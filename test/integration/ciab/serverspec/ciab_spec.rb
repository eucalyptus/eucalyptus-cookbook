require 'serverspec'

set :backend, :exec

describe "Eucalyptus CIAB" do
  
  %w{eucalyptus-cloud eucalyptus-cc eucanetd
     eucalyptus-nc eucaconsole eucalyptus-sc
     eucalyptus-walrus}.each do |package_name| 
       describe package(package_name) do
         it { should be_installed }
       end
  end

  %w{8773 8774 8775 8888}.each do |port_number|
     describe port(port_number) do
       it { should be_listening }
     end
  end

  %w{eucalyptus-cloud eucalyptus-cc eucanetd
     eucalyptus-nc eucaconsole}.each do |service_name|
     describe service(service_name) do
       it { should be_enabled }
       it { should be_running }
     end
  end

  describe command('euca-version') do
    it { should return_stdout /euca2ools.*3\.1/ }
    it { should return_stdout /eucalyptus.*4\.0/ }
  end

  describe selinux do
    it { should be_disabled }
  end

  describe command('ping -c 1 `hostname --fqd`') do
    its(:exit_status) { should eq 0 }
  end
end
