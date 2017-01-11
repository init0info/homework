# About

Code test homework.  Setup a Jenkins server, form a build pipeline for a 'hello world' application.  Deploy the application to a server.

# Prerequisites:

## Install KVM (libvirt) on laptop - kernel-based virtualization.

## Install Vagrant on laptop

# Initialize the project
1. Clone this repository
2. Ensure that all the submodules in the site-cookbooks directory have been cloned

# To build the project infrastructure:
1. `vagrant init centos/7` _this pulls the Centos 7 box from the Atlas box repo_
2. `vagrant up`
3. Jenkins server becomes available at http://192.168.33.9:8080/
4. Web content server becomes available at http://192.168.33.9:3000/

# Setup details

## The vagrant file:

1. run two machines: jenkins and web
2. assign hostnames to the servers
3. update memory settings for the VM's in Vagrantfile
3. change provisioning on both boxes to chef
4. update the vagrant file with vm configs to provision with chef
5. be sure to run `vagrant destroy` after all the updates to the Vagrantfile

## Chef settings

1. jenkins_server cookbook
   * installs java
   * installs jenkins master server
2. web server cookbook
   * installs sqlite3
   * installs Ruby on Rails


# To Do:

1. use chef to
   * set hostnames
   * update or upgrade (yum update && yum upgrade)
   * add net-tools to both boxes
   * install and enable SELinux
