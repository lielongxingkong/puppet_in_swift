#
# This class can be used to manage keystone's authtoken middleware
# for swift proxy
#
# == Parameters
#  [admin_token] Keystone admin token that can serve as a shared secret
#    for authenticating. If this is choosen if is used instead of a user,tenant,password.
#    Optional. Defaults to false.
#  [admin_user] User used to authenticate service.
#    Optional. Defaults to admin
#  [admin_tenant_name] Tenant used to authenticate service.
#    Optional. Defaults to openstack.
#  [admin_password] Password used with user to authenticate service.
#    Optional. Defaults to ChangeMe.
#  [delay_decision] Set to 1 to support token-less access (anonymous access,
#    tempurl, ...)
#    Optional, Defaults to 0
#  [auth_host] Host providing the keystone service API endpoint. Optional.
#    Defaults to 127.0.0.1
#  [auth_port] Port where keystone service is listening. Optional.
#    Defaults to 3557.
#  [auth_protocol] Protocol to use to communicate with keystone. Optional.
#    Defaults to https.
#  [auth_admin_prefix] path part of the auth url. Optional.
#    This allows admin auth URIs like http://host/keystone/admin/v2.0.
#    Defaults to false for empty. It defined, should be a string with a leading '/' and no trailing '/'.
#  [auth_uri] The public auth url to redirect unauthenticated requests.
#    Defaults to false to be expanded to '${auth_protocol}://${auth_host}:5000'.
#    Should be set to your public keystone endpoint (without version).
#
# == Authors
#
#   Dan Bode dan@puppetlabs.com
#
# == Copyright
#
# Copyright 2012 Puppetlabs Inc, unless otherwise noted.
#

class swift::proxy::authtoken(
  $admin_user          = 'swift',
  $admin_tenant_name   = 'services',
  $admin_password      = 'password',
  $auth_host           = '127.0.0.1',
  $auth_port           = '35357',
  $auth_protocol       = 'http',
  $auth_admin_prefix   = false,
  $auth_uri            = false,
  $delay_auth_decision = 1,
  $admin_token         = false,
  $service_port        = 5000,
  $service_host        = '127.0.0.1',
  $signing_dir         = '/etc/swift'

) {

  if $auth_uri {
    $auth_uri_real = $auth_uri
  } else {
    $auth_uri_real = "${auth_protocol}://${auth_host}:5000"
  }
  $fragment_title    = regsubst($name, '/', '_', 'G')

  if $auth_admin_prefix {
    validate_re($auth_admin_prefix, '^(/.+[^/])?$')
  }

  concat::fragment { "swift_authtoken":
    target  => '/etc/swift/proxy-server.conf',
    content => template('swift/proxy/authtoken.conf.erb'),
    order   => '22',
  }

}
