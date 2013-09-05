require 'spec_helper'

describe 'swift' do

  let :params do
    {:swift_hash_suffix => 'string'}
  end

  let :facts do
    {
      :operatingsystem => 'Ubuntu',
      :osfamily        => 'Debian'
    }
  end

  describe 'when no swift hash is specified' do
    let :params do
      {}
    end
    it 'should raise an exception' do
      expect { subject }.to raise_error(Puppet::Error)
    end
  end


  describe 'when using the default value for package_ensure' do
    let :file_defaults do
      {
        :owner   => 'swift',
        :group   => 'swift',
        :require => 'Package[swift]'
      }
    end
    it {should contain_file('/home/swift').with(
      {:ensure => 'directory', :mode => '0700'
      }.merge(file_defaults)
    )}
    it {should contain_file('/etc/swift').with(
      {:ensure => 'directory', :mode => '2770'
      }.merge(file_defaults)
    )}
    it {should contain_file('/var/run/swift').with(
      {:ensure => 'directory'}.merge(file_defaults)
    )}
    it {should contain_file('/var/cache/swift').with(
      {:ensure => 'directory'}.merge(file_defaults)
    )}
    it {should contain_file('/etc/swift/swift.conf').with(
      {:ensure  => 'present',
       :mode    => '0660',
       :content => "[swift-hash]\nswift_hash_path_suffix = string\n"
      }.merge(file_defaults)
    )}
    it {should contain_package('swift').with_ensure('present')}
    it {should contain_user('swift')}
    it {should contain_file('/var/lib/swift').with_ensure('directory')}
  end

  describe 'when overriding package_ensure parameter' do
    it 'should effect ensure state of swift package' do
      params[:package_ensure] = 'latest'
      subject.should contain_package('swift').with_ensure('latest')
    end
  end

end
