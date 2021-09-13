# Puppet Enterprise & Terraform Demo

This repository contains a terraform project used for demo purposes.  
It can be used to showcase using Terraform and Puppet together to provision and manage infrastructure.  
The terraform project will deploy...  
1. Core infrastructure (a VPC and 2 public subnets, route table, internet gateway etc.)
1. A Puppet Enterprise primary server including...
	1. EC2 instance w/ bootstrap script, SSH key, security groups, public and private DNS records (Route53), application load balancer with listeners, target groups, and SSL certificates.
	1. Code manager configured and synced with a private control repository in GitHub
	1. A predefined Puppet role applied (must exist in the control repository)
1. Unlimited custom nodes of any size, type, with any Puppet role we provide.
	- When created, nodes will be registered with Puppet Enterprise, and apply the role we assign.
	- When destroyed, nodes will be purged from Puppet Enterprise.

## Disclaimer

This repository is only intended to be used for demo purposes, and should not be used in a real or production environment.  
For use in a real environment, you should consider things like...  
- IAM roles
- Separate public and private subnets with appropriate network and security restrictions
- Additional and more restricted security groups
- Using a real secrets manager for ssh keys, passwords etc.
- Load balancer health-checks
- A more restricted method for Puppet Enterprise certificate autosigning.
- A designated user and token (not admin) for Puppet Enterprise console access and Code Manager sync
- Probably lots more...

## Workstation Prerequisites

This demo repository was used and tested on MacOS Big Sur 11.5 with the following tools installed and configured...
- Apple Xcode Command Line Tools
- Homebrew
- AWS CLI
- Terraform

## Platform & Application Prerequisites

This demo can optionally create a new VPC and Subnets using the provided CIDR blocks in the [terraform.tfvars.json](terraform.tfvars.json) file.  
This demo requires the following resources to already exist...  
- AWS
	- An existing Route 53 Public Zone (your.publicdomain.com)
	- An existing Route 53 Private Zone (your.privatedomain.com)
	- An ACM Wildcard Certificate for the Public Zone (*.your.publicdomain.com)
- GitHub
	- A GitHub PAT (Personal Access Token), saved into a local file referenced in the `github_token` variable in [terraform.tfvars.json](terraform.tfvars.json).

## Configure

1. Modyify the values in [terraform.tfvars.json](terraform.tfvars.json) to suit your purposes. Ensure that:
	1. The `project_id` is unique in your environment so as not to not conflict with other project names used in the account - it is used for unique naming of resources.
  	1. Update `allowed_ip_cidrs` with your public IP CIDR (and any others you want) so you are permitted to access project resources.
	1. If you ARE using an existing VPC and existing subnets, set `create_vpc_and_subnets` to `false`, and make sure the CIDR blocks provided match what you will be using.
	1. If you are NOT using an existing VPC and existing subnets, set `create_vpc_and_subnets` to `true`, and make sure the CIDR blocks provided do not already exist in your environment.
	1. Make sure `control_repo` exists and is a valid Puppet control repository.
	1. Make sure your provided `github_token` file contains a valid PAT to your GitHub account.
	1. Make sure the `pe_primary_role`, `pe_primary_environment`, `role`, `environment` variables are all valid roles and environments in your control repository.
1. The [deploy.sh](deploy.sh) script currently uses the `aws sso login` command to log in to AWS, you may need to update this to fit your needs.

## Deploying

```sh
./deploy.sh
# authenticate if required
```

#### Deploying using terraform manually

```sh
# authenticate if required
terraform init # only required on first run or when providers\modules are added\updated
terraform plan # optional
terraform apply
```

## Displaying output

```sh
./deploy.sh --output
# authenticate if required
```

### Destroying

```sh
./deploy.sh --destroy
# authenticate if required
```

#### Destroying using terraform manually

```sh
# authenticate if required
terraform destroy
```
