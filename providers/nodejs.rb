#
# Author:: Conrad Kramer <conrad@kramerapps.com>
# Cookbook Name:: application_node
# Resource:: node
#
# Copyright:: 2013, Kramer Software Productions, LLC. <conrad@kramerapps.com>
#
# Licensed under the Apache License, Version 2.0 (the 'License');
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an 'AS IS' BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include Chef::DSL::IncludeRecipe

action :before_compile do

  include_recipe 'nodejs::nodejs_from_package'

  r = new_resource

  if new_resource.npm
    include_recipe 'nodejs::npm'
  end

  unless new_resource.restart_command
    new_resource.restart_command do

      service "#{r.application.name}_nodejs" do
        if platform?('ubuntu') && node[:platform_version].to_f >= 14.04
          provider Chef::Provider::Service::Systemd
        else
          provider Chef::Provider::Service::Upstart
        end
        supports :restart => true, :start => true, :stop => true
        action [:enable, :restart]
      end

    end
  end

  new_resource.environment.update({
    'NODE_ENV' => r.environment_name
  })

end

action :before_deploy do

  new_resource.environment['NODE_ENV'] = new_resource.environment_name

  r = new_resource

  service "#{r.application.name}_nodejs" do
    if platform?('ubuntu') && node[:platform_version].to_f >= 14.04
      provider Chef::Provider::Service::Systemd
    else
      provider Chef::Provider::Service::Upstart
    end
  end

  if platform?('ubuntu') && node[:platform_version].to_f >= 14.04
    execute "systemctl daemon-reload" do
      command "systemctl daemon-reload"
      action :nothing
    end

    template "#{r.application.name}_nodejs.systemd.service.erb" do
      path "/lib/systemd/system/#{r.application.name}_nodejs.service"
      source r.template ? r.template : 'nodejs.systemd.service.erb'
      cookbook r.template ? r.cookbook_name.to_s : 'application_nodejs'
      owner 'root'
      group 'root'
      mode '0644'
      variables(
        :user => r.owner,
        :group => r.group,
        :app_dir => r.release_path,
        :entry => r.entry_point,
        :environment => r.environment
      )
      notifies :run, "execute[systemctl daemon-reload]", :delayed
      notifies :restart, "service[#{r.application.name}_nodejs]", :delayed
    end
  else
    template "#{new_resource.application.name}.upstart.conf" do
      path "/etc/init/#{r.application.name}_nodejs.conf"
      source r.template ? r.template : 'nodejs.upstart.conf.erb'
      cookbook r.template ? r.cookbook_name.to_s : 'application_nodejs'
      owner 'root'
      group 'root'
      mode '0644'
      variables(
        :user => r.owner,
        :group => r.group,
        :app_dir => r.release_path,
        :entry => r.entry_point,
        :environment => r.environment
      )
      notifies :restart, "service[#{r.application.name}_nodejs]", :delayed
    end
  end
end

action :before_migrate do

  if new_resource.npm
    execute 'npm install' do
      cwd new_resource.release_path
      user new_resource.owner
      group new_resource.group
      environment new_resource.environment.merge({ 'HOME' => new_resource.shared_path })
    end
  end

end

action :before_symlink do
end

action :before_restart do
end

action :after_restart do
end
