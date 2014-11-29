#
# Cookbook Name:: tomcat_bin
# Provider:: default
#
# Copyright 2014 Brian Clark
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

use_inline_resources if defined?(use_inline_resources)

def whyrun_supported?
  true
end

action :configure do
  setenv_sh = ::File.join(new_resource.home, 'bin', 'setenv.sh')
  server_xml = ::File.join(new_resource.home, 'conf', 'server.xml')
  logging_properties =
    ::File.join(new_resource.home, 'conf', 'logging.properties')

  template "/etc/init.d/#{new_resource.name}" do
    source 'tomcat.init.erb'
    variables(
      tomcat_home: new_resource.home,
      tomcat_user: new_resource.user,
      tomcat_name: new_resource.name
    )
    mode 0755
    owner 'root'
    group 'root'
    cookbook new_resource.init_cookbook
  end

  template setenv_sh do
    source 'setenv.sh.erb'
    mode 0755
    owner new_resource.user
    group new_resource.group
    variables(
      tomcat_home: new_resource.home,
      java_home: new_resource.java_home,
      catalina_opts: new_resource.catalina_opts,
      java_opts: new_resource.java_opts,
      additional: new_resource.setenv_opts
    )
    cookbook new_resource.setenv_cookbook
  end

  template server_xml do
    source 'server.xml.erb'
    mode 0755
    owner new_resource.user
    group new_resource.group
    variables(
      shutdown_port: new_resource.shutdown_port,
      thread_pool: new_resource.thread_pool,
      http: new_resource.http,
      ssl: new_resource.ssl,
      ajp: new_resource.ajp,
      engine_valves: new_resource.engine_valves,
      default_host: new_resource.default_host,
      default_host_valves: new_resource.default_host_valves,
      access_log_valve: new_resource.access_log_valve
    )
    cookbook new_resource.server_xml_cookbook
  end

  template logging_properties do
    source 'logging.properties.erb'
    mode 0755
    owner new_resource.user
    group new_resource.group
    variables(
      use_logrotate: new_resource.use_logrotate
    )
    cookbook new_resource.logging_properties_cookbook
  end

  logfiles = [
    'catalina.out',
    'catalina.log',
    'manager.log',
    'host-manager.log',
    'localhost.log',
    new_resource.access_log_valve['prefix'] +
      new_resource.access_log_valve['suffix']
  ].map { |logfile| ::File.join(new_resource.home, 'logs', logfile) }

  template "/etc/logrotate.d/#{new_resource.name}" do
    source 'logrotate.erb'
    mode 0644
    owner 'root'
    group 'root'
    variables(
      files: logfiles,
      frequency: new_resource.logrotate_frequency,
      rotate: new_resource.logrotate_rotate
    )
    cookbook new_resource.logrotate_cookbook
    only_if { new_resource.use_logrotate }
  end

  service new_resource.name do
    supports restart: true, start: true, stop: true, status: true
    action [:enable, :start]
    subscribes :restart, "template[/etc/init.d/#{new_resource.name}]"
    subscribes :restart, "template[#{server_xml}]"
    subscribes :restart, "template[#{setenv_sh}]"
    subscribes :restart, "template[#{logging_properties}]"
  end
end
