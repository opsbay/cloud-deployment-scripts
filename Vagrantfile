# -*- mode: ruby -*-
# vi: set ft=ruby :

# Vagrantfile for testing Ansible scripts and CodeDeploy hook scripts

# Thanks Stack Overflow https://stackoverflow.com/a/25918153/424301
required_plugins = %w( vagrant-vbguest vagrant-triggers )
required_plugins.each do |plugin|
  system "vagrant plugin install #{plugin}" unless Vagrant.has_plugin? plugin
end

# Override via environment variable
#
# Other tested settings are "centos/7" and "ubuntu/xenial64"
# Supported OS's:
#  - Ubuntu Server 14.04 LTS
#  - Microsoft Windows Server 2016, 2012 R2, and 2008 R2
#  - Red Hat Enterprise Linux (RHEL) 7.x
# See: http://docs.aws.amazon.com/codedeploy/latest/userguide/codedeploy-agent.html#codedeploy-agent-supported-operating-systems
default_vagrantbox = "centos/6"
default_playbook = "site.yml"
default_region = "us-east-1"
default_splunk_forwarder = "127.0.0.0"
default_profile = "default"
# Thanks Stack Overflow https://stackoverflow.com/a/18449271/424301
vagrant_root = File.dirname(__FILE__)
vagrantbox_file="#{vagrant_root}/.vagrantbox"
if ENV['VAGRANTBOX']
    open(vagrantbox_file, 'w') { |f|
      f.puts(ENV['VAGRANTBOX'])
    }
end
if File.exist?(vagrantbox_file)
    vagrantbox = File.read(vagrantbox_file).strip
else
    vagrantbox =  default_vagrantbox
end

playbook = ENV['PLAYBOOK'] || default_playbook
splunk_forwarder = ENV['SPLUNK_FORWARDER'] ||  default_splunk_forwarder
region = ENV['AWS_DEFAULT_REGION'] || default_region
profile = ENV['AWS_DEFAULT_PROFILE'] || default_profile

tmp_env_path = "/tmp/aws_env.sh"

Vagrant.configure("2") do |config|

  config.vm.box = vagrantbox
  config.vm.network "forwarded_port", guest: 80, host: 8880
  config.vm.provider "virtualbox" do |vb|
     vb.memory = "1024"
  end

  # The destroy hook needs the AWS creds in the root dir.
  config.vm.synced_folder "#{ENV['HOME']}/.aws",
    "/root/.aws",
    type: "virtualbox"

  config.vm.synced_folder ".",
    "/vagrant",
    type: "virtualbox"

  config.vm.provision "shell",
    path: "packer/bin/install-ansible.sh",
    upload_path: "./install-ansible.sh"

  config.vm.provision "file",
    source: "env.sh",
    destination: "#{tmp_env_path}"

  # This is set so that import_users.sh and authorized_keys_command.sh scripts
  # are able to run against the dev environment. This relies on the
  # {ENV['HOME']}/.aws folder being synced to /root/.aws
  config.vm.provision "shell",
    inline: "cp #{tmp_env_path} /etc/profile.d/aws_env.sh"

  # We used to use the ansible provisioner here, but since we
  # want to support running Vagrant on Windows 10, we need to
  # run Ansible using the shell provisioner instead, since
  # as of 2017-04-25, Windows Vagrant does not support the
  # Ansible provisioner.
  config.vm.provision "shell",
    args: [region, playbook, splunk_forwarder],
    path: "packer/bin/run-ansible.sh",
    upload_path: "./run-ansible.sh"

  # Runs on 'vagrant up'
  config.vm.provision "shell",
    path: "codedeploy/on-premise/setup.sh",
    upload_path: "./on-premise-setup.sh",
    args: ["up", profile]

  # Runs on 'vagrant destroy'
  # TODO: Investigate how we can cause this to also run on `vagrant reload --provision`.
  ### We should trigger on :up also, but check to see if we have been provisioned yet.
  ### Then we can also hook into :resume, :suspend, and :halt
  config.trigger.before :destroy do
  info "Removing CodeDeploy user"
  run_remote  "bash /vagrant/codedeploy/on-premise/setup.sh down #{profile}"
  end
end
