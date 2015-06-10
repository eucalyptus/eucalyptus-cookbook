name             'eucalyptus'
maintainer       'Vic Iglesias'
maintainer_email 'viglesiasce@gmail.com'
license          'Apache 2'
description      'Installs/Configures eucalyptus'
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          '0.4.0'
depends          'yum'
depends          'ntp'
depends          'selinux'
depends          'ceph-cluster'
depends          'riakcs-cluster'
depends          'midokura'
