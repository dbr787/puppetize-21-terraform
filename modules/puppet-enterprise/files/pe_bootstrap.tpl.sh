#!/bin/bash

set -x

timedatectl set-timezone Australia/Melbourne || exit 1

# template file parameters
hostname="${hostname}"
zone="${zone}"
pe_version="${pe_version}"
pe_admin_password="${pe_admin_password}"
role="${role}"
environment="${environment}"
control_repo="${control_repo}"
github_token="${github_token}"
code_manager_dns="${code_manager_dns}"

# local script parameters
PATH="$PATH:/opt/puppetlabs/bin"
work_dir="/tmp"
pe_installer_url="https://pm.puppet.com/cgi-bin/download.cgi?dist=el&rel=7&arch=x86_64&ver=$pe_version"
fqdn="$hostname.$zone"

# working directory
mkdir -p "$work_dir" && cd "$_"

# set hostname and host records
hostnamectl set-hostname "$fqdn"
echo "HOSTNAME=$fqdn" >> /etc/sysconfig/networking
echo "127.0.0.1 $fqdn $hostname" >> /etc/hosts

# create puppet directory
mkdir -p /etc/puppetlabs/puppet

# configure autsigning
echo "*" > /etc/puppetlabs/puppet/autosign.conf

# set csr_attributes
cat > /etc/puppetlabs/puppet/csr_attributes.yaml << YAML
---
extension_requests:
  pp_role: '${role}'
  pp_environment: '${environment}'
  pp_hostname: '${hostname}'
  pp_zone: '${zone}'
YAML

# set pe.conf
cat > /tmp/pe.conf << EOF
{
  "console_admin_password": "${pe_admin_password}"
  "puppet_enterprise::puppet_master_host": "%%{::trusted.certname}"
  "puppet_enterprise::profile::console::display_local_time": true
  "puppet_enterprise::profile::console::rbac_session_timeout": 4320
  "pe_install::puppet_master_dnsaltnames": ["puppet"]
  "puppet_enterprise::profile::master::code_manager_auto_configure": true
  "puppet_enterprise::profile::master::r10k_remote": "${control_repo}"
  "puppet_enterprise::profile::master::r10k_private_key": "/etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa"
}
EOF

# install puppet enterprise
pe_installer_url="https://pm.puppet.com/cgi-bin/download.cgi?dist=el&rel=7&arch=x86_64&ver=$pe_version"
curl -JLO "$pe_installer_url"
tar -xzf puppet*.tar.gz
cd puppet*
./puppet-enterprise-installer -c /tmp/pe.conf

# do a few puppet runs
for i in {1..2}; do puppet agent -t; done

# generate access token
echo "$pe_admin_password" | puppet access login --username admin --lifetime 10y # saves token to ~/.puppetlabs/token

###############################################
# set up code manager and webhook deploy key
###############################################

# install epel (extra packages for enterprize linux)
yum -y install https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
# install jq
yum -y install jq

repo_name=$(echo $control_repo | sed -e 's/git@github.com:\(.*\).git/\1/')
deploy_key_name="puppet_deploy_key"
webhook_contains="code-manager/v1/webhook?type=github"
deploy_keys=$(curl https://api.github.com/repos/$repo_name/keys -H "Authorization: token $github_token")
webhooks=$(curl https://api.github.com/repos/$repo_name/hooks -H "Authorization: token $github_token")

# create key pair
key_file="/etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa"
echo "Creating key pair: $key_file"
ssh-keygen -N '' -f $key_file -C https://github.com/$repo_name <<<y >/dev/null 2>&1
chmod 750 /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa
chown pe-puppet:pe-puppet /etc/puppetlabs/puppetserver/ssh/id-control_repo.rsa

# delete github deploy key (if exists)
if [[ $deploy_keys == *"$deploy_key_name"* ]]; then
    deploy_key_urls=$(echo $deploy_keys | jq -r --arg deploy_key_name "$deploy_key_name" '.[] | select(.title == $deploy_key_name) | .url')
    echo $deploy_key_urls | while read deploy_key_url; do
    echo "Deleting existing deploy key: $deploy_key_url"
    curl -X DELETE "$deploy_key_url" -H "Authorization: token $github_token" 
    done
else
    echo "No existing deploy key found: $deploy_key_name"
fi

# create github deploy key
echo "Creating deploy key: $deploy_key_name"
public_key=$(<$key_file.pub)
curl -X POST \
    https://api.github.com/repos/$repo_name/keys \
    -H "Authorization: token $github_token" \
    -d '{
        "title": "'"$deploy_key_name"'",
        "key": "'"$public_key"'",
        "read_only": true
    }'

# delete github webhook (if exists)
if [[ $webhooks == *"$webhook_contains"* ]]; then
    webhook_urls=$(echo $webhooks | jq -r --arg webhook_name "$webhook_contains" '.[] | select(.config.url | contains("code-manager/v1/webhook?type=github")) | .url')
    echo $webhook_urls | while read webhook_url; do
    echo "Deleting existing webhook: $webhook_url"
    curl -X DELETE "$webhook_url" -H "Authorization: token $github_token" 
    done
else
    echo "No existing webhook found containing: $webhook_contains"
fi

# create github webhook
echo "Creating webhook"
puppet_token=`cat ~/.puppetlabs/token`
curl -X POST \
    https://api.github.com/repos/$repo_name/hooks \
    -H "authorization: token $github_token" \
    -d '{
        "config": {
            "url": "'"$code_manager_dns/code-manager/v1/webhook?type=github&token=$puppet_token"'",
            "content_type": "json",
            "insecure_ssl": 0
        },
        "events": [
            "push"
        ]
    }'

# run a manual code deploy
puppet code deploy --all --wait

# do a few puppet runs
for i in {1..3}; do puppet agent -t; sleep 10; done
