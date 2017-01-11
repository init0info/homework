# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure("2") do |config|
  # The most common configuration options are documented and commented below.
  # For a complete reference, please see the online documentation at
  # https://docs.vagrantup.com.

  # Every Vagrant development environment requires a box. You can search for
  # boxes at https://atlas.hashicorp.com/search.
  config.vm.box = "centos/7"

  config.vm.define "jenkins" do |jenkins|
    # settings for the jenkins node

    jenkins.vm.provider :libvirt do |domain|
      domain.memory = 1024
    end

    # Create a private network, which allows host-only access to the machine
    # using a specific IP.
    jenkins.vm.network "private_network", ip: "192.168.33.9"

    jenkins.vm.provision "shell", inline: "echo jenkins > /etc/hostname"

    jenkins.vm.provision "chef_solo" do |chef|
      chef.cookbooks_path = ["cookbooks", "site-cookbooks"]
      chef.node_name = "jenkins_master"
      chef.add_recipe "jenkins_server"
    end
  end

  config.vm.define "web" do |web|
    # settings for the  web node

    web.vm.provider :libvirt do |domain|
      domain.memory = 1024
    end

    # Create a private network, which allows host-only access to the machine
    # using a specific IP.
    web.vm.network "private_network", ip: "192.168.33.10"

    web.vm.provision "shell", inline: "echo web > /etc/hostname"

    web.vm.provision "chef_solo" do |chef|
      chef.cookbooks_path = ["cookbooks", "site-cookbooks"]
      chef.node_name = "web_1"
      chef.add_recipe "web_server"
    end
  end
end
