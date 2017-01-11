Install KVM (libvirt) on laptop

Install Vagrant on laptop

# Create the first machine in Vagrant
vagrant init centos/7; vagrant up --provider libvirt
# this pulls the Centos 7 box from the Atlas box repo

# Update the vagrant file to run two machines: jenkins and web

# vagrant destroy previously created boxes

# update memory settings for the VM's in Vagrantfile

# change provisioning on both boxes to chef
## update the vagrant file with vm configs to provision with chef
## create cookbooks with "chef generate cookbook ..."

# add jenkins recipe

# configure jenkins recipe to install java

to do:

# use chef supermarket libs to:

# set hostnames

# update or upgrade (yum update && yum upgrade)

# add net-tools to both boxes (can be done with .vm.provision :shell, inline: "yum install net-tools" but better with chef cookbooks)

# install and enable SELinux
