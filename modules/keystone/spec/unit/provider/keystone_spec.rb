require 'puppet'
require 'spec_helper'
require 'puppet/provider/keystone'
require 'tempfile'


klass = Puppet::Provider::Keystone

describe Puppet::Provider::Keystone do

  after :each do
    klass.reset
  end


  describe 'when retrieving the security token' do

    it 'should fail if there is no keystone config file' do
      ini_file = Puppet::Util::IniConfig::File.new
      t = Tempfile.new('foo')
      path = t.path
      t.unlink
      ini_file.read(path)
      expect do
        klass.get_admin_token
      end.to raise_error(Puppet::Error, /Keystone types will not work/)
    end

    it 'should fail if the keystone config file does not have a DEFAULT section' do
      mock = {}
      Puppet::Util::IniConfig::File.expects(:new).returns(mock)
      mock.expects(:read).with('/etc/keystone/keystone.conf')
      expect do

        klass.get_admin_token
      end.to raise_error(Puppet::Error, /Keystone types will not work/)
    end

    it 'should fail if the keystone config file does not contain an admin token' do
      mock = {'DEFAULT' => {'not_a_token' => 'foo'}}
      Puppet::Util::IniConfig::File.expects(:new).returns(mock)
      mock.expects(:read).with('/etc/keystone/keystone.conf')
      expect do
       klass.get_admin_token
      end.to raise_error(Puppet::Error, /Keystone types will not work/)
    end

    it 'should parse the admin token if it is in the config file' do
      mock = {'DEFAULT' => {'admin_token' => 'foo'}}
      Puppet::Util::IniConfig::File.expects(:new).returns(mock)
      mock.expects(:read).with('/etc/keystone/keystone.conf')
      klass.get_admin_token.should == 'foo'
    end

    it 'should use the specified bind_host in the admin endpoint' do
      mock = {'DEFAULT' => {'bind_host' => '192.168.56.210', 'admin_port' => '35357' }}
      Puppet::Util::IniConfig::File.expects(:new).returns(mock)
      mock.expects(:read).with('/etc/keystone/keystone.conf')
      klass.get_admin_endpoint.should == 'http://192.168.56.210:35357/v2.0/'
    end

    it 'should use localhost in the admin endpoint if bind_host is 0.0.0.0' do
      mock = {'DEFAULT' => { 'bind_host' => '0.0.0.0', 'admin_port' => '35357' }}
      Puppet::Util::IniConfig::File.expects(:new).returns(mock)
      mock.expects(:read).with('/etc/keystone/keystone.conf')
      klass.get_admin_endpoint.should == 'http://127.0.0.1:35357/v2.0/'
    end

    it 'should use localhost in the admin endpoint if bind_host is unspecified' do
      mock = {'DEFAULT' => { 'admin_port' => '35357' }}
      Puppet::Util::IniConfig::File.expects(:new).returns(mock)
      mock.expects(:read).with('/etc/keystone/keystone.conf')
      klass.get_admin_endpoint.should == 'http://127.0.0.1:35357/v2.0/'
    end

    describe 'when testing keystone connection retries' do

      ['[Errno 111] Connection refused', '(HTTP 400)', 'HTTP Unable to establish connection'].reverse.each do |valid_message|
        it "should retry when keystone is not ready with error #{valid_message}" do
          mock = {'DEFAULT' => {'admin_token' => 'foo'}}
          Puppet::Util::IniConfig::File.expects(:new).returns(mock)
          mock.expects(:read).with('/etc/keystone/keystone.conf')
          klass.expects(:sleep).with(10).returns(nil)
          klass.expects(:keystone).twice.with('--endpoint', 'http://127.0.0.1:35357/v2.0/', ['test_retries']).raises(Exception, valid_message).then.returns('')
          klass.auth_keystone('test_retries')
        end
      end
    end

  end

  describe 'when keystone cli has warnings' do
    it "should remove errors from results" do
      mock = {'DEFAULT' => {'admin_token' => 'foo'}}
      Puppet::Util::IniConfig::File.expects(:new).returns(mock)
      mock.expects(:read).with('/etc/keystone/keystone.conf')
      klass.expects(
        :keystone
      ).with(
        '--endpoint',
        'http://127.0.0.1:35357/v2.0/',
        ['test_retries']
      ).returns("WARNING\n+-+-+\nWARNING")
      klass.auth_keystone('test_retries').should == "+-+-+\nWARNING"
    end
  end
end
