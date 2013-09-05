#
# Example file for building out a multi-node environment
#
# This example creates nodes of the following roles:
#   swift_storage - nodes that host storage servers
#   swift_proxy - nodes that serve as a swift proxy
#   swift_ringbuilder - nodes that are responsible for
#     rebalancing the rings
#
# This example assumes a few things:
#   * the multi-node scenario requires a puppetmaster
#   * it assumes that networking is correctly configured
#
# These nodes need to be brought up in a certain order
#
# 1. storage nodes
# 2. ringbuilder
# 3. run the storage nodes again (to synchronize the ring db)
# 4. run the proxy
# 5. test that everything works!!
# this site manifest serves as an example of how to
# deploy various swift environments


$swift_admin_password = 'admin'
#$swift_admin_password = hiera('admin_password', 'admin')

 # swift specific configurations
$swift_shared_secret = 'randomestringchangeme'
#$swift_shared_secret = hiera('swift_shared_secret', 'randomestringchangeme')


$swift_local_net_ip   = $ipaddress_eth1
#$swift_local_net_ip = hiera('swift_local_net_ip', $ipaddress_eth1)

$swift_keystone_node = '192.168.9.11'
#$swift_keystone_node    = hiera('swift_keystone_node', '192.168.9.11')
$swift_proxy_node    = '192.168.9.11'
#$swift_proxy_node       = hiera('swift_proxy_node', '192.168.9.11')

#$swift_zone = hiera('swift_zone', 7)
$swift_zone = 7
# configurations that need to be applied to all swift nodes

#$swift_keystone_db_password    = hiera('keystone_db_password', 'keystone')
#$keystone_admin_token          = hiera('admin_token', '33092fa356a0837f703c')
#$swift_keystone_admin_email    = hiera('admin_email', 'keystone@localhost')
#$swift_keystone_admin_password = hiera('admin_password', 'admin')

#$swift_verbose                 = hiera('verbose', 'True')

$swift_keystone_db_password    = 'keystone'
$keystone_admin_token          = '33092fa356a0837f703c'
$swift_keystone_admin_email    = 'keystone@localhost'
$swift_keystone_admin_password = 'admin'
$swift_verbose                 = 'True'

$mysql_root_password = '1q2w3e4r'

# This node can be used to deploy a keystone service.
# This service only contains the credentials for authenticating
# swift
node keystone {

  # set up mysql server
  class { 'mysql::server':
    config_hash => {
      # the priv grant fails on precise if I set a root password
      # TODO I should make sure that this works
      'root_password' => $mysql_root_password,
      'bind_address'  => '0.0.0.0'
    }
  }

  keystone_config {
    'DEFAULT/log_config': ensure => absent,
  }

  # set up all openstack databases, users, grants
  class { 'keystone::db::mysql':
    password => $swift_keystone_db_password,
  }

  class { '::keystone':
    verbose        => $verbose,
    debug          => $verbose,
    catalog_type   => 'sql',
    admin_token    => $keystone_admin_token,
    enabled        => $enabled,
    sql_connection => "mysql://keystone_admin:${swift_keystone_db_password}@127.0.0.1/keystone",
  }

  # Setup the Keystone Identity Endpoint
  class { 'keystone::endpoint': }

  # set up keystone admin users
  class { 'keystone::roles::admin':
    email    => $swift_keystone_admin_email,
    password => $swift_keystone_admin_password,
  }
  # configure the keystone service user and endpoint
  class { 'swift::keystone::auth':
    password => $swift_admin_password,
    address  => $swift_proxy_node,
  }

}


node swift_base  {


  class { 'swift':
    # not sure how I want to deal with this shared secret
    swift_hash_suffix => $swift_shared_secret,
    package_ensure    => latest,
  }

}

#
# The example below is used to model swift storage nodes that
# manage 2 endpoints.
#
# The endpoints are actually just loopback devices. For real deployments
# they would need to be replaced with something that create and mounts xfs
# partitions
#
node /datanode01/ inherits swift_base {

  # create xfs partitions on a loopback device and mount them
  swift::storage::disk { ['c0d1']:
    base_dir     => '/dev/cciss',
    mnt_base_dir => '/srv/node',
    require      => Class['swift'],
  }

  class { 'zabbixagent': 
    servers => '192.168.9.1',
    hostname => 'datanode01',
  }

  # install all swift storage servers together
  class { 'swift::storage::all':
    storage_local_net_ip => $swift_local_net_ip,
    statsd_enable => true,
    statsd_server_ip => '192.168.9.1',
    statsd_server_port => 8126,
    statsd_hostname => 'datanode01',
  }

  # specify endpoints per device to be added to the ring specification
  @@ring_object_device { "${swift_local_net_ip}:6000/c0d1":
    zone        => 1,
    weight      => 1000,
  }


  @@ring_container_device { "${swift_local_net_ip}:6001/c0d1":
    zone        => 1,
    weight      => 1000,
  }

  # TODO should device be changed to volume
  @@ring_account_device { "${swift_local_net_ip}:6002/c0d1":
    zone        => 1,
    weight      => 1000,
  }


  # collect resources for synchronizing the ring databases
  Swift::Ringsync<<||>>

}

node /datanode02/ inherits swift_base {

  # create xfs partitions on a loopback device and mount them
  swift::storage::disk { ['c0d1']:
    base_dir     => '/dev/cciss',
    mnt_base_dir => '/srv/node',
    require      => Class['swift'],
  }

  class { 'zabbixagent': 
    servers => '192.168.9.1',
    hostname => 'datanode02',
  }

  # install all swift storage servers together
  class { 'swift::storage::all':
    storage_local_net_ip => $swift_local_net_ip,
    statsd_enable => true,
    statsd_server_ip => '192.168.9.1',
    statsd_server_port => 8126,
    statsd_hostname => 'datanode02',
  }

  # specify endpoints per device to be added to the ring specification
  @@ring_object_device { "${swift_local_net_ip}:6000/c0d1":
    zone        => 2,
    weight      => 1000,
  }


  @@ring_container_device { "${swift_local_net_ip}:6001/c0d1":
    zone        => 2,
    weight      => 1000,
  }

  # TODO should device be changed to volume
  @@ring_account_device { "${swift_local_net_ip}:6002/c0d1":
    zone        => 2,
    weight      => 1000,
  }


  # collect resources for synchronizing the ring databases
  Swift::Ringsync<<||>>

}

node /datanode03/ inherits swift_base {

  # create xfs partitions on a loopback device and mount them
  swift::storage::disk { ['c0d1']:
    base_dir     => '/dev/cciss',
    mnt_base_dir => '/srv/node',
    require      => Class['swift'],
  }

  class { 'zabbixagent': 
    servers => '192.168.9.1',
    hostname => 'datanode03',
  }

  # install all swift storage servers together
  class { 'swift::storage::all':
    storage_local_net_ip => $swift_local_net_ip,
    statsd_enable => true,
    statsd_server_ip => '192.168.9.1',
    statsd_server_port => 8126,
    statsd_hostname => 'datanode03',
  }

  # specify endpoints per device to be added to the ring specification
  @@ring_object_device { "${swift_local_net_ip}:6000/c0d1":
    zone        => 3,
    weight      => 1000,
  }


  @@ring_container_device { "${swift_local_net_ip}:6001/c0d1":
    zone        => 3,
    weight      => 1000,
  }

  # TODO should device be changed to volume
  @@ring_account_device { "${swift_local_net_ip}:6002/c0d1":
    zone        => 3,
    weight      => 1000,
  }


  # collect resources for synchronizing the ring databases
  Swift::Ringsync<<||>>

}

node /datanode04/ inherits swift_base {

  # create xfs partitions on a loopback device and mount them
  swift::storage::disk { ['c0d1']:
    base_dir     => '/dev/cciss',
    mnt_base_dir => '/srv/node',
    require      => Class['swift'],
  }

  class { 'zabbixagent': 
    servers => '192.168.9.1',
    hostname => 'datanode04',
  }

  # install all swift storage servers together
  class { 'swift::storage::all':
    storage_local_net_ip => $swift_local_net_ip,
    statsd_enable => true,
    statsd_server_ip => '192.168.9.1',
    statsd_server_port => 8126,
    statsd_hostname => 'datanode04',
  }

  # specify endpoints per device to be added to the ring specification
  @@ring_object_device { "${swift_local_net_ip}:6000/c0d1":
    zone        => 4,
    weight      => 1000,
  }


  @@ring_container_device { "${swift_local_net_ip}:6001/c0d1":
    zone        => 4,
    weight      => 1000,
  }

  # TODO should device be changed to volume
  @@ring_account_device { "${swift_local_net_ip}:6002/c0d1":
    zone        => 4,
    weight      => 1000,
  }


  # collect resources for synchronizing the ring databases
  Swift::Ringsync<<||>>

}

node /datanode05/ inherits swift_base {

  # create xfs partitions on a loopback device and mount them
  swift::storage::disk { ['c0d1']:
    base_dir     => '/dev/cciss',
    mnt_base_dir => '/srv/node',
    require      => Class['swift'],
  }

  class { 'zabbixagent': 
    servers => '192.168.9.1',
    hostname => 'datanode05',
  }

  # install all swift storage servers together
  class { 'swift::storage::all':
    storage_local_net_ip => $swift_local_net_ip,
    statsd_enable => true,
    statsd_server_ip => '192.168.9.1',
    statsd_server_port => 8126,
    statsd_hostname => 'datanode05',
  }

  # specify endpoints per device to be added to the ring specification
  @@ring_object_device { "${swift_local_net_ip}:6000/c0d1":
    zone        => 5,
    weight      => 1000,
  }


  @@ring_container_device { "${swift_local_net_ip}:6001/c0d1":
    zone        => 5,
    weight      => 1000,
  }

  # TODO should device be changed to volume
  @@ring_account_device { "${swift_local_net_ip}:6002/c0d1":
    zone        => 5,
    weight      => 1000,
  }


  # collect resources for synchronizing the ring databases
  Swift::Ringsync<<||>>

}

node /datanode06/ inherits swift_base {

  # create xfs partitions on a loopback device and mount them
  swift::storage::disk { ['c0d1']:
    base_dir     => '/dev/cciss',
    mnt_base_dir => '/srv/node',
    require      => Class['swift'],
  }

  class { 'zabbixagent': 
    servers => '192.168.9.1',
    hostname => 'datanode06',
  }

  # install all swift storage servers together
  class { 'swift::storage::all':
    storage_local_net_ip => $swift_local_net_ip,
    statsd_enable => true,
    statsd_server_ip => '192.168.9.1',
    statsd_server_port => 8126,
    statsd_hostname => 'datanode06',
  }

  # specify endpoints per device to be added to the ring specification
  @@ring_object_device { "${swift_local_net_ip}:6000/c0d1":
    zone        => 6,
    weight      => 1000,
  }


  @@ring_container_device { "${swift_local_net_ip}:6001/c0d1":
    zone        => 6,
    weight      => 1000,
  }

  # TODO should device be changed to volume
  @@ring_account_device { "${swift_local_net_ip}:6002/c0d1":
    zone        => 6,
    weight      => 1000,
  }


  # collect resources for synchronizing the ring databases
  Swift::Ringsync<<||>>

}

node /datanode07/ inherits swift_base {

  # create xfs partitions on a loopback device and mount them
  swift::storage::disk { ['c0d1']:
    base_dir     => '/dev/cciss',
    mnt_base_dir => '/srv/node',
    require      => Class['swift'],
  }

  class { 'zabbixagent': 
    servers => '192.168.9.1',
    hostname => 'datanode07',
  }

  # install all swift storage servers together
  class { 'swift::storage::all':
    storage_local_net_ip => $swift_local_net_ip,
    statsd_enable => true,
    statsd_server_ip => '192.168.9.1',
    statsd_server_port => 8126,
    statsd_hostname => 'datanode07',
  }

  # specify endpoints per device to be added to the ring specification
  @@ring_object_device { "${swift_local_net_ip}:6000/c0d1":
    zone        => 7,
    weight      => 1000,
  }


  @@ring_container_device { "${swift_local_net_ip}:6001/c0d1":
    zone        => 7,
    weight      => 1000,
  }

  # TODO should device be changed to volume
  @@ring_account_device { "${swift_local_net_ip}:6002/c0d1":
    zone        => 7,
    weight      => 1000,
  }


  # collect resources for synchronizing the ring databases
  Swift::Ringsync<<||>>

}


node /proxy01/ inherits swift_base {

  class { 'swift::proxy':
    proxy_local_net_ip => $swift_local_net_ip,
    pipeline           => [
#      'catch_errors',
      'healthcheck',
      'cache',
#      'ratelimit',
#      'swift3',
#      's3token',
      'authtoken',
      'keystoneauth',
      'proxy-logging',
      'proxy-server'
    ],
    statsd_enable => true,
    statsd_server_ip => '192.168.9.1',
    statsd_server_port => 8126,
    statsd_default_sample_rate => 1.0,
    statsd_sample_rate_factor => 1.0,
    statsd_hostname => 'proxy01',
    account_autocreate => true,
    # TODO where is the  ringbuilder class?
    require            => Class['swift::ringbuilder'],
  }

  # curl is only required so that I can run tests
  package { 'curl': ensure => present }

  class { 'memcached':
    listen_ip => '127.0.0.1',
  }

  # specify swift proxy and all of its middlewares

  # configure all of the middlewares
  class { 'swift::proxy::ratelimit':
    clock_accuracy         => 1000,
    max_sleep_time_seconds => 60,
    log_sleep_time_seconds => 0,
    rate_buffer_seconds    => 5,
    account_ratelimit      => 0
  }
 
  class { 'swift::proxy::keystoneauth':
    operator_roles => ['admin', 'Member'],
  }
  class { 'swift::proxy::authtoken':
    admin_user        => 'swift',
    admin_tenant_name => 'services',
    admin_password    => $swift_admin_password,
    # assume that the controller host is the swift api server
    auth_host         => $swift_keystone_node,
    service_host      => $swift_keystone_node,
    service_port      => 5000
  }
  class { 'swift::proxy::s3token':
    # assume that the controller host is the swift api server
    auth_host     => $swift_keystone_node,
    auth_port     => '35357',
  }
  class { [
#    'swift::proxy::catch_errors',
    'swift::proxy::healthcheck',
    'swift::proxy::cache',
    'swift::proxy::swift3',
    'swift::proxy::proxy-logging',
  ]: }

  # collect all of the resources that are needed
  # to balance the ring
  Ring_object_device <<| |>>
  Ring_container_device <<| |>>
  Ring_account_device <<| |>>

  # create the ring
  class { 'swift::ringbuilder':
    # the part power should be determined by assuming 100 partitions per drive
    part_power     => '18',
    replicas       => '3',
    min_part_hours => 1,
    require        => Class['swift'],
  }

  # sets up an rsync db that can be used to sync the ring DB
  class { 'swift::ringserver':
    local_net_ip => $swift_local_net_ip,
  }

  # exports rsync gets that can be used to sync the ring files
  @@swift::ringsync { ['account', 'object', 'container']:
   ring_server => $swift_local_net_ip
 }

  # deploy a script that can be used for testing
  class { 'swift::test_file':
    auth_server => $swift_keystone_node,
    password    => $swift_keystone_admin_password,
  }
}



node /proxy02/ inherits swift_base {
  $swift_local_net_ip = $ipaddress_eth0
  class { 'swift::proxy':
    proxy_local_net_ip => $swift_local_net_ip,
    pipeline           => [
#      'catch_errors',
      'healthcheck',
      'cache',
#      'ratelimit',
#      'swift3',
#      's3token',
      'authtoken',
      'keystoneauth',
      'proxy-logging',
      'proxy-server'
    ],
    statsd_enable => true,
    statsd_server_ip => '192.168.9.1',
    statsd_server_port => 8126,
    statsd_default_sample_rate => 1.0,
    statsd_sample_rate_factor => 1.0,
    statsd_hostname => 'proxy02',
    account_autocreate => true,
    # TODO where is the  ringbuilder class?
    require            => Class['swift::ringbuilder'],
  }

  # curl is only required so that I can run tests
  package { 'curl': ensure => present }

  class { 'memcached':
    listen_ip => '127.0.0.1',
  }

  # specify swift proxy and all of its middlewares

  # configure all of the middlewares
  class { 'swift::proxy::ratelimit':
    clock_accuracy         => 1000,
    max_sleep_time_seconds => 60,
    log_sleep_time_seconds => 0,
    rate_buffer_seconds    => 5,
    account_ratelimit      => 0
  }
 
  class { 'swift::proxy::keystoneauth':
    operator_roles => ['admin', 'Member'],
  }
  class { 'swift::proxy::authtoken':
    admin_user        => 'swift',
    admin_tenant_name => 'services',
    admin_password    => $swift_admin_password,
    # assume that the controller host is the swift api server
    auth_host         => $swift_keystone_node,
    service_host      => $swift_keystone_node,
    service_port      => 5000
  }
  class { 'swift::proxy::s3token':
    # assume that the controller host is the swift api server
    auth_host     => $swift_keystone_node,
    auth_port     => '35357',
  }
  class { [
#    'swift::proxy::catch_errors',
    'swift::proxy::healthcheck',
    'swift::proxy::cache',
    'swift::proxy::swift3',
    'swift::proxy::proxy-logging',
  ]: }

  # collect all of the resources that are needed
  # to balance the ring
  Ring_object_device <<| |>>
  Ring_container_device <<| |>>
  Ring_account_device <<| |>>

  # create the ring
  class { 'swift::ringbuilder':
    # the part power should be determined by assuming 100 partitions per drive
    part_power     => '18',
    replicas       => '3',
    min_part_hours => 1,
    require        => Class['swift'],
  }

  # sets up an rsync db that can be used to sync the ring DB
  class { 'swift::ringserver':
    local_net_ip => $swift_local_net_ip,
  }

  # exports rsync gets that can be used to sync the ring files
  @@swift::ringsync { ['account', 'object', 'container']:
   ring_server => $swift_local_net_ip
 }

  # deploy a script that can be used for testing
  class { 'swift::test_file':
    auth_server => $swift_keystone_node,
    password    => $swift_keystone_admin_password,
  }
}





node /proxy03/ inherits swift_base {
  $swift_local_net_ip = $ipaddress_eth0
  class { 'swift::proxy':
    proxy_local_net_ip => $swift_local_net_ip,
    pipeline           => [
#      'catch_errors',
      'healthcheck',
      'cache',
#      'ratelimit',
#      'swift3',
#      's3token',
      'authtoken',
      'keystoneauth',
      'proxy-logging',
      'proxy-server'
    ],
    statsd_enable => true,
    statsd_server_ip => '192.168.9.1',
    statsd_server_port => 8126,
    statsd_default_sample_rate => 1.0,
    statsd_sample_rate_factor => 1.0,
    statsd_hostname => 'proxy03',
    account_autocreate => true,
    # TODO where is the  ringbuilder class?
    require            => Class['swift::ringbuilder'],
  }

  # curl is only required so that I can run tests
  package { 'curl': ensure => present }

  class { 'zabbixagent':
    servers => '192.168.9.1',
    hostname => 'proxy03',
  }  

  class { 'memcached':
    listen_ip => '127.0.0.1',
  }

  # specify swift proxy and all of its middlewares

  # configure all of the middlewares
  class { 'swift::proxy::ratelimit':
    clock_accuracy         => 1000,
    max_sleep_time_seconds => 60,
    log_sleep_time_seconds => 0,
    rate_buffer_seconds    => 5,
    account_ratelimit      => 0
  }
 
  class { 'swift::proxy::keystoneauth':
    operator_roles => ['admin', 'Member'],
  }
  class { 'swift::proxy::authtoken':
    admin_user        => 'swift',
    admin_tenant_name => 'services',
    admin_password    => $swift_admin_password,
    # assume that the controller host is the swift api server
    auth_host         => $swift_keystone_node,
    service_host      => $swift_keystone_node,
    service_port      => 5000
  }
  class { 'swift::proxy::s3token':
    # assume that the controller host is the swift api server
    auth_host     => $swift_keystone_node,
    auth_port     => '35357',
  }
  class { [
#    'swift::proxy::catch_errors',
    'swift::proxy::healthcheck',
    'swift::proxy::cache',
    'swift::proxy::swift3',
    'swift::proxy::proxy-logging',
  ]: }

  # collect all of the resources that are needed
  # to balance the ring
  Ring_object_device <<| |>>
  Ring_container_device <<| |>>
  Ring_account_device <<| |>>

  # create the ring
  class { 'swift::ringbuilder':
    # the part power should be determined by assuming 100 partitions per drive
    part_power     => '18',
    replicas       => '3',
    min_part_hours => 1,
    require        => Class['swift'],
  }

  # sets up an rsync db that can be used to sync the ring DB
  class { 'swift::ringserver':
    local_net_ip => $swift_local_net_ip,
  }

  # exports rsync gets that can be used to sync the ring files
  @@swift::ringsync { ['account', 'object', 'container']:
   ring_server => $swift_local_net_ip
 }

  # deploy a script that can be used for testing
  class { 'swift::test_file':
    auth_server => $swift_keystone_node,
    password    => $swift_keystone_admin_password,
  }
}

