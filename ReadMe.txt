Ansible Collection - ami_base.linux
This collection allows users to configure their Linux base machines. It includes functionality such as installing AWS CLI, configuring time zone, and adding trusted CA certificates.

Roles Included in ami_base.linux Collection:
role_awscli
role_cacert
role_cloudwatch
role_cte_agent
role_jq
role_mdatp
role_nbu
role_newrelic
role_prereq
role_servicenow
role_sysstat
role_tenable
role_timezone_cdt
Using Collection in Playbook
Example Playbook
- name: Playbook for Configuring Linux Base
  hosts: platform_linux
  collections:
    - ami_base.linux

  roles:
    - ami_base.linux.role_cacert
Dependencies
ansible-core version >= 2.12.2

Setting up Collection Locally
Add configuration for downloading from Private Automation Hub

In ansible.cfg file include:
[galaxy]
server_list = published_repo 

[galaxy_server.published_repo]
url=https://aap-hub-1.apissa.aws.alight.com/api/galaxy/content/published/
token= (token from PAH)
Downloading this collection
ansible-galaxy collection install ami_base.linux -c