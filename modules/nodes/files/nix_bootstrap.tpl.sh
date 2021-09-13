#!/bin/bash

set -x

# set templatefile and local parameters
hostname="${hostname}"
zone="${zone}"
pe_primary=${pe_primary}
role="${role}"
environment="${environment}"
fqdn="$hostname.$zone"

# retry loop to download and install puppet agent
echo "downloading puppet agent from puppet server"
n=1
t=100
while [ "$n" -le "$t" ]
do
  curl --insecure --connect-timeout 5 --max-time 10 "https://$pe_primary:8140/packages/current/install.bash" -o install.bash
  if [ -f "./install.bash" ]; then
    echo "attempt $n of $t: download succeeded, running install script"
    bash ./install.bash agent:certname=$fqdn extension_requests:pp_role=$role extension_requests:pp_environment=$environment extension_requests:pp_hostname=$fqdn extension_requests:pp_zone=$zone
    sleep 20
    break
  elif [ "$n" -lt "$t" ]; then
    echo "attempt $n of $t: download failed, trying again in 10s"
    n=$((n+1))
    sleep 5
  else
    echo "attempt $n of $t: unable to download puppet agent after $n tries, exiting script"
    exit 1
  fi
done

# do a few puppet runs
for i in {1..10}; do /opt/puppetlabs/bin/puppet agent -t; sleep 30; done

exit 0
