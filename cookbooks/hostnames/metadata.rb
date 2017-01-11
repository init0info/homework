# -*- coding: utf-8 -*-

name             'hostnames'
maintainer       'Nathan Tsoi'
maintainer_email 'nathan@vertile.com'
license          'MIT'
description      'Configures hostname and FQDN'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.4.1'

supports 'debian'
supports 'ubuntu'
supports 'freebsd'
supports 'centos'
supports 'redhat'
supports 'amazon'
supports 'scientific'

depends 'hostsfile'
