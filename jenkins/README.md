# Jenkins configuration

This directory contains Jenkins configuration snippets that are not otherwise tracked for our [AWS Jenkins Server](https://jenkins.devops.naviance.com/).

Script         | Purpose | Location
---------------|---------|--------
init_script.sh | Configure Cloud AWS instances, configured in "Cloud...AWS...init script"| [configure](https://jenkins.devops.naviance.com/configure)
Jenkinsfile-update-dns-entries | Updates DNS entries for terraform-created EC2 instances | [update-dns-entries](https://jenkins.devops.naviance.com/job/Utility-Jobs/job/update-dns-entries/)
Jenkinsfile-execute-remote-command | Executes a command on a remote cron server | [execute-remote-command](https://jenkins.devops.naviance.com/job/Utility-Jobs/job/execute-remote-command/)