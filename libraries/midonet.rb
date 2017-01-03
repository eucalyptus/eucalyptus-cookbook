# Executes Bash command and returns the output
def execute_command(cmd)
  Chef::Log.info "Executing: #{cmd}"
  cmd = Mixlib::ShellOut::new(cmd)
  cmd.run_command.stdout
end

def get_mn_template(mn_template)
  cmd = Mixlib::ShellOut::new("mn-conf dump -t #{mn_template}")
  cmd.run_command
  {
    :is_empty => cmd.stdout =~ /{}/,
    :result => cmd.stdout.strip,
  }
end

# Check if a service is currently running/active
# If service_status(service_name)[:is_active] returns nil
# if the service is not running/active
def service_status(service_name)
  cmd = Mixlib::ShellOut::new("systemctl is-active #{service_name}")
  cmd.run_command
  {
    :is_active => cmd.stdout.strip == "active",
    :result => cmd.stdout.strip,
  }
end

def get_property(cmd, value)
  cmd = Mixlib::ShellOut::new(cmd)
  cmd.run_command
  {
    :is_configured => cmd.stdout =~ /#{value}/,
    :result => cmd.stdout.strip,
  }
end

def get_mn_http_port(mn_port)
  cmd = "mn-conf get cluster.rest_api.http_port"
  get_property(cmd, mn_port)
end

def get_mn_http_host(mn_host)
  cmd = "mn-conf get cluster.rest_api.http_host"
  get_property(cmd, mn_host)
end

def get_midolman_template(midolman_template)
  cmd = "mn-conf template-get -h local"
  get_property(cmd, midolman_template)
end
