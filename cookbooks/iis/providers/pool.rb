#
# Author:: Kendrick Martin (kendrick.martin@webtrends.com)
# Contributor:: David Dvorak (david.dvorak@webtrends.com)
# Cookbook Name:: iis
# Provider:: pool
#
# Copyright:: 2011, Webtrends Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'chef/mixin/shell_out'
require 'rexml/document'

include Chef::Mixin::ShellOut
include REXML
include Opscode::IIS::Helper
include Opscode::IIS::Processors

action :add do
  if !@current_resource.exists
    cmd = "#{appcmd(node)} add apppool /name:\"#{new_resource.pool_name}\""
    if new_resource.no_managed_code
      cmd << ' /managedRuntimeVersion:'
    elsif new_resource.runtime_version
      cmd << " /managedRuntimeVersion:v#{new_resource.runtime_version}"
    end
    cmd << " /managedPipelineMode:#{new_resource.pipeline_mode.capitalize}" if new_resource.pipeline_mode
    cmd << ' /commit:\"MACHINE/WEBROOT/APPHOST\"'
    Chef::Log.debug(cmd)
    shell_out!(cmd)
    configure
    new_resource.updated_by_last_action(true)
    Chef::Log.info('App pool created')
  else
    Chef::Log.debug("#{new_resource} pool already exists - nothing to do")
  end
end

action :config do
  new_resource.updated_by_last_action(true) if configure
end

action :delete do
  if @current_resource.exists
    shell_out!("#{appcmd(node)} delete apppool \"#{site_identifier}\"")
    new_resource.updated_by_last_action(true)
    Chef::Log.info("#{new_resource} deleted")
  else
    Chef::Log.debug("#{new_resource} pool does not exist - nothing to do")
  end
end

action :start do
  if !@current_resource.running
    shell_out!("#{appcmd(node)} start apppool \"#{site_identifier}\"")
    new_resource.updated_by_last_action(true)
    Chef::Log.info("#{new_resource} started")
  else
    Chef::Log.debug("#{new_resource} already running - nothing to do")
  end
end

action :stop do
  if @current_resource.running
    shell_out!("#{appcmd(node)} stop apppool \"#{site_identifier}\"")
    new_resource.updated_by_last_action(true)
    Chef::Log.info("#{new_resource} stopped")
  else
    Chef::Log.debug("#{new_resource} already stopped - nothing to do")
  end
end

action :restart do
  shell_out!("#{appcmd(node)} stop APPPOOL \"#{site_identifier}\"")
  sleep 2
  shell_out!("#{appcmd(node)} start APPPOOL \"#{site_identifier}\"")
  new_resource.updated_by_last_action(true)
  Chef::Log.info("#{new_resource} restarted")
end

action :recycle do
  shell_out!("#{appcmd(node)} recycle APPPOOL \"#{site_identifier}\"")
  new_resource.updated_by_last_action(true)
  Chef::Log.info("#{new_resource} recycled")
end

def load_current_resource
  @current_resource = Chef::Resource::IisPool.new(new_resource.name)
  @current_resource.pool_name(new_resource.pool_name)
  cmd = shell_out("#{appcmd(node)} list apppool")
  # APPPOOL "DefaultAppPool" (MgdVersion:v2.0,MgdMode:Integrated,state:Started)
  Chef::Log.debug("#{new_resource} list apppool command output: #{cmd.stdout}")
  if cmd.stderr.empty?
    result = cmd.stdout.gsub(/\r\n?/, "\n") # ensure we have no carriage returns
    result = result.match(/^APPPOOL\s\"(#{new_resource.pool_name})\"\s\(MgdVersion:(.*),MgdMode:(.*),state:(.*)\)$/i)
    Chef::Log.debug("#{new_resource} current_resource match output: #{result}")
    if result
      @current_resource.exists = true
      @current_resource.running = (result[4] =~ /Started/) ? true : false
    else
      @current_resource.exists = false
      @current_resource.running = false
    end
  else
    log "Failed to run iis_pool action :load_current_resource, #{cmd.stderr}" do
      level :warn
    end
  end
end

private

def site_identifier
  new_resource.pool_name
end

def configure
  @was_updated = false
  cmd_current_values = "#{appcmd(node)} list apppool \"#{new_resource.pool_name}\" /config:* /xml"
  Chef::Log.debug(cmd_current_values)
  cmd_current_values = shell_out(cmd_current_values)
  if cmd_current_values.stderr.empty?
    xml = cmd_current_values.stdout
    doc = Document.new(xml)

    # root items
    is_new_managed_runtime_version =
      if new_resource.no_managed_code
        new_value?(doc.root, 'APPPOOL/@RuntimeVersion', '')
      else
        new_value?(doc.root, 'APPPOOL/@RuntimeVersion', "v#{new_resource.runtime_version}")
      end
    is_new_pipeline_mode = new_value?(doc.root, 'APPPOOL/@PipelineMode', new_resource.pipeline_mode)

    # add items
    if iis_version >= '7.0'
      is_new_auto_start = new_value?(doc.root, 'APPPOOL/add/@autoStart', new_resource.auto_start.to_s)
    end

    if iis_version > '7.0'
      is_new_start_mode = new_value?(doc.root, 'APPPOOL/add/@startMode', new_resource.start_mode.to_s)
    end

    is_new_queue_length = new_value?(doc.root, 'APPPOOL/add/@queueLength', new_resource.queue_length.to_s)
    is_new_enable_32_bit_app_on_win_64 = new_value?(doc.root, 'APPPOOL/add/@enable32BitAppOnWin64', new_resource.thirty_two_bit.to_s)

    # processModel items
    is_new_max_processes = new_or_empty_value?(doc.root, 'APPPOOL/add/processModel/@maxProcesses', new_resource.max_proc.to_s)
    is_new_load_user_profile = new_value?(doc.root, 'APPPOOL/add/processModel/@loadUserProfile', new_resource.load_user_profile.to_s)
    if iis_version > '7.0'
      is_new_identity_type = new_value?(doc.root, 'APPPOOL/add/processModel/@identityType', new_resource.pool_identity.to_s)
    end
    is_new_user_name = new_or_empty_value?(doc.root, 'APPPOOL/add/processModel/@userName', new_resource.pool_username.to_s)
    is_new_password = new_or_empty_value?(doc.root, 'APPPOOL/add/processModel/@password', new_resource.pool_password.to_s)
    if iis_version > '7.0'
      is_new_logon_type = new_value?(doc.root, 'APPPOOL/add/processModel/@logonType', new_resource.logon_type.to_s)
    end
    is_new_manual_group_membership = new_value?(doc.root, 'APPPOOL/add/processModel/@manualGroupMembership', new_resource.manual_group_membership.to_s)
    is_new_idle_timeout = new_value?(doc.root, 'APPPOOL/add/processModel/@idleTimeout', new_resource.idle_timeout.to_s)
    if iis_version >= '8.5'
      is_new_idle_timeout_action = new_value?(doc.root, 'APPPOOL/add/processModel/@idleTimeoutAction', new_resource.idle_timeout_action)
    end
    is_new_shutdown_time_limit = new_value?(doc.root, 'APPPOOL/add/processModel/@shutdownTimeLimit', new_resource.shutdown_time_limit.to_s)
    is_new_startup_time_limit = new_value?(doc.root, 'APPPOOL/add/processModel/@startupTimeLimit', new_resource.startup_time_limit.to_s)
    is_new_pinging_enabled = new_value?(doc.root, 'APPPOOL/add/processModel/@pingingEnabled', new_resource.pinging_enabled.to_s)
    is_new_ping_interval = new_value?(doc.root, 'APPPOOL/add/processModel/@pingInterval', new_resource.ping_interval.to_s)
    is_new_ping_response_time = new_value?(doc.root, 'APPPOOL/add/processModel/@pingResponseTime', new_resource.ping_response_time.to_s)

    # failure items
    is_new_load_balancer_capabilities = new_value?(doc.root, 'APPPOOL/add/failure/@loadBalancerCapabilities', new_resource.load_balancer_capabilities.to_s)
    is_new_orphan_worker_process = new_value?(doc.root, 'APPPOOL/add/failure/@orphanWorkerProcess', new_resource.orphan_worker_process.to_s)
    is_new_orphan_action_exe = new_or_empty_value?(doc.root, 'APPPOOL/add/failure/@orphanActionExe', new_resource.orphan_action_exe.to_s)
    is_new_orphan_action_params = new_or_empty_value?(doc.root, 'APPPOOL/add/failure/@orphanActionParams', new_resource.orphan_action_params.to_s)
    is_new_rapid_fail_protection = new_value?(doc.root, 'APPPOOL/add/failure/@rapidFailProtection', new_resource.rapid_fail_protection.to_s)
    is_new_rapid_fail_protection_interval = new_value?(doc.root, 'APPPOOL/add/failure/@rapidFailProtectionInterval', new_resource.rapid_fail_protection_interval.to_s)
    is_new_rapid_fail_protection_max_crashes = new_value?(doc.root, 'APPPOOL/add/failure/@rapidFailProtectionMaxCrashes', new_resource.rapid_fail_protection_max_crashes.to_s)
    is_new_auto_shutdown_exe = new_or_empty_value?(doc.root, 'APPPOOL/add/failure/@autoShutdownExe', new_resource.auto_shutdown_exe.to_s)
    is_new_auto_shutdown_params = new_or_empty_value?(doc.root, 'APPPOOL/add/failure/@autoShutdownParams', new_resource.auto_shutdown_params.to_s)

    # recycling items
    is_new_disallow_overlapping_rotation = new_value?(doc.root, 'APPPOOL/add/recycling/@disallowOverlappingRotation', new_resource.disallow_overlapping_rotation.to_s)
    is_new_disallow_rotation_on_config_change = new_value?(doc.root, 'APPPOOL/add/recycling/@disallowRotationOnConfigChange', new_resource.disallow_rotation_on_config_change.to_s)
    is_new_recycle_after_time = new_or_empty_value?(doc.root, 'APPPOOL/add/recycling/periodicRestart/@time', new_resource.recycle_after_time.to_s)
    is_new_recycle_at_time = new_or_empty_value?(doc.root, "APPPOOL/add/recycling/periodicRestart/schedule/add[@value='#{new_resource.recycle_at_time}']/@value", new_resource.recycle_at_time.to_s)
    is_new_private_memory = new_or_empty_value?(doc.root, 'APPPOOL/add/recycling/periodicRestart/@privateMemory', new_resource.private_mem.to_s)
    is_new_virtual_memory = new_or_empty_value?(doc.root, 'APPPOOL/add/recycling/periodicRestart/@memory', new_resource.virtual_mem.to_s)
    is_new_log_event_on_recycle = new_or_empty_value?(doc.root, 'APPPOOL/add/recycling/@logEventOnRecycle', new_resource.log_event_on_recycle.to_s)

    # cpu items
    is_new_cpu_action = new_value?(doc.root, 'APPPOOL/add/cpu/@action', new_resource.cpu_action.to_s)
    is_new_cpu_limit = new_value?(doc.root, 'APPPOOL/add/cpu/@limit', new_resource.cpu_limit.to_s)
    is_new_cpu_smp_affinitized = new_value?(doc.root, 'APPPOOL/add/cpu/@smpAffinitized', new_resource.cpu_smp_affinitized.to_s)
    is_new_cpu_reset_interval = new_value?(doc.root, 'APPPOOL/add/cpu/@resetInterval', new_resource.cpu_reset_interval.to_s)
    is_new_smp_processor_affinity_mask = new_value?(doc.root, 'APPPOOL/add/cpu/@smpProcessorAffinityMask', new_resource.smp_processor_affinity_mask.floor)
    is_new_smp_processor_affinity_mask_2 = new_value?(doc.root, 'APPPOOL/add/cpu/@smpProcessorAffinityMask2', new_resource.smp_processor_affinity_mask_2.floor)

    # Application Pool Config
    @cmd = "#{appcmd(node)} set config /section:applicationPools"

    # root items
    if iis_version >= '7.0'
      configure_application_pool(is_new_auto_start, "autoStart:#{new_resource.auto_start}")
    end

    if iis_version >= '7.5'
      configure_application_pool(is_new_start_mode, "startMode:#{new_resource.start_mode}")
    end

    if new_resource.no_managed_code
      configure_application_pool(is_new_managed_runtime_version, 'managedRuntimeVersion:')
    else
      configure_application_pool(new_resource.runtime_version && is_new_managed_runtime_version, "managedRuntimeVersion:v#{new_resource.runtime_version}")
    end
    configure_application_pool(new_resource.pipeline_mode && is_new_pipeline_mode, "managedPipelineMode:#{new_resource.pipeline_mode}")
    configure_application_pool(is_new_enable_32_bit_app_on_win_64, "enable32BitAppOnWin64:#{new_resource.thirty_two_bit}")
    configure_application_pool(new_resource.queue_length && is_new_queue_length, "queueLength:#{new_resource.queue_length}")

    # processModel items
    configure_application_pool(new_resource.max_proc && is_new_max_processes, "processModel.maxProcesses:#{new_resource.max_proc}")
    configure_application_pool(is_new_load_user_profile, "processModel.loadUserProfile:#{new_resource.load_user_profile}")
    configure_application_pool(is_new_logon_type, "processModel.logonType:#{new_resource.logon_type}")
    configure_application_pool(is_new_manual_group_membership, "processModel.manualGroupMembership:#{new_resource.manual_group_membership}")
    configure_application_pool(is_new_idle_timeout, "processModel.idleTimeout:#{new_resource.idle_timeout}")
    if iis_version >= '8.5'
      configure_application_pool(is_new_idle_timeout_action, "processModel.idleTimeoutAction:#{new_resource.idle_timeout_action}")
    end
    configure_application_pool(is_new_shutdown_time_limit, "processModel.shutdownTimeLimit:#{new_resource.shutdown_time_limit}")
    configure_application_pool(is_new_startup_time_limit, "processModel.startupTimeLimit:#{new_resource.startup_time_limit}")
    configure_application_pool(is_new_pinging_enabled, "processModel.pingingEnabled:#{new_resource.pinging_enabled}")
    configure_application_pool(is_new_ping_interval, "processModel.pingInterval:#{new_resource.ping_interval}")
    configure_application_pool(is_new_ping_response_time, "processModel.pingResponseTime:#{new_resource.ping_response_time}")

    node_array = XPath.match(doc.root, 'APPPOOL/add/recycling/periodicRestart/schedule/add')
    should_clear_apppool_schedules = ((new_resource.recycle_at_time && is_new_recycle_at_time) && !node_array.empty?) || (new_resource.recycle_schedule_clear && !node_array.empty?)

    # recycling items
    ## Special case this collection removal for now.
    if should_clear_apppool_schedules
      @was_updated = true
      is_new_recycle_at_time = true
      clear_pool_schedule_cmd = "#{appcmd(node)} set config /section:applicationPools \"/-[name='#{new_resource.pool_name}'].recycling.periodicRestart.schedule\""
      Chef::Log.debug(clear_pool_schedule_cmd)
      shell_out!(clear_pool_schedule_cmd)
    end

    configure_application_pool(new_resource.recycle_after_time && is_new_recycle_after_time, "recycling.periodicRestart.time:#{new_resource.recycle_after_time}")
    configure_application_pool(new_resource.recycle_at_time && is_new_recycle_at_time, "recycling.periodicRestart.schedule.[value='#{new_resource.recycle_at_time}']", '+')
    configure_application_pool(new_resource.log_event_on_recycle && is_new_log_event_on_recycle, "recycling.logEventOnRecycle:#{new_resource.log_event_on_recycle}")
    configure_application_pool(new_resource.private_mem && is_new_private_memory, "recycling.periodicRestart.privateMemory:#{new_resource.private_mem}")
    configure_application_pool(new_resource.virtual_mem && is_new_virtual_memory, "recycling.periodicRestart.memory:#{new_resource.virtual_mem}")
    configure_application_pool(is_new_disallow_rotation_on_config_change, "recycling.disallowRotationOnConfigChange:#{new_resource.disallow_rotation_on_config_change}")
    configure_application_pool(is_new_disallow_overlapping_rotation, "recycling.disallowOverlappingRotation:#{new_resource.disallow_overlapping_rotation}")

    # failure items
    configure_application_pool(is_new_load_balancer_capabilities, "failure.loadBalancerCapabilities:#{new_resource.load_balancer_capabilities}")
    configure_application_pool(is_new_orphan_worker_process, "failure.orphanWorkerProcess:#{new_resource.orphan_worker_process}")
    configure_application_pool(new_resource.orphan_action_exe && is_new_orphan_action_exe, "failure.orphanActionExe:#{new_resource.orphan_action_exe}")
    configure_application_pool(new_resource.orphan_action_params && is_new_orphan_action_params, "failure.orphanActionParams:#{new_resource.orphan_action_params}")
    configure_application_pool(is_new_rapid_fail_protection, "failure.rapidFailProtection:#{new_resource.rapid_fail_protection}")
    configure_application_pool(is_new_rapid_fail_protection_interval, "failure.rapidFailProtectionInterval:#{new_resource.rapid_fail_protection_interval}")
    configure_application_pool(is_new_rapid_fail_protection_max_crashes, "failure.rapidFailProtectionMaxCrashes:#{new_resource.rapid_fail_protection_max_crashes}")
    configure_application_pool(new_resource.auto_shutdown_exe && is_new_auto_shutdown_exe, "failure.autoShutdownExe:#{new_resource.auto_shutdown_exe}")
    configure_application_pool(new_resource.auto_shutdown_params && is_new_auto_shutdown_params, "failure.autoShutdownParams:#{new_resource.auto_shutdown_params}")

    # cpu items
    configure_application_pool(is_new_cpu_action, "cpu.action:#{new_resource.cpu_action}")
    configure_application_pool(is_new_cpu_limit, "cpu.limit:#{new_resource.cpu_limit}")
    configure_application_pool(is_new_cpu_reset_interval, "cpu.resetInterval:#{new_resource.cpu_reset_interval}")
    configure_application_pool(is_new_cpu_smp_affinitized, "cpu.smpAffinitized:#{new_resource.cpu_smp_affinitized}")
    configure_application_pool(is_new_smp_processor_affinity_mask, "cpu.smpProcessorAffinityMask:#{new_resource.smp_processor_affinity_mask.floor}")
    configure_application_pool(is_new_smp_processor_affinity_mask_2, "cpu.smpProcessorAffinityMask2:#{new_resource.smp_processor_affinity_mask_2.floor}")

    if @cmd != "#{appcmd(node)} set config /section:applicationPools"
      Chef::Log.debug(@cmd)
      shell_out!(@cmd)
    end

    # Application Pool Identity Settings
    if (new_resource.pool_username && new_resource.pool_username != '') && (is_new_user_name || is_new_password)
      @was_updated = true
      cmd = "#{appcmd(node)} set config /section:applicationPools"
      cmd << " \"/[name='#{new_resource.pool_name}'].processModel.identityType:SpecificUser\""
      cmd << " \"/[name='#{new_resource.pool_name}'].processModel.userName:#{new_resource.pool_username}\""
      cmd << " \"/[name='#{new_resource.pool_name}'].processModel.password:#{new_resource.pool_password}\"" if new_resource.pool_password && new_resource.pool_password != '' && is_new_password
      Chef::Log.debug(cmd)
      shell_out!(cmd)
    elsif (new_resource.pool_username.nil? || new_resource.pool_username == '') &&
          (new_resource.pool_password.nil? || new_resource.pool_username == '') &&
          (is_new_identity_type && new_resource.pool_identity != 'SpecificUser')
      @was_updated = true
      cmd = "#{appcmd(node)} set config /section:applicationPools"
      cmd << " \"/[name='#{new_resource.pool_name}'].processModel.identityType:#{new_resource.pool_identity}\""
      Chef::Log.debug(cmd)
      shell_out!(cmd)
    end

    if @was_updated
      Chef::Log.info("#{new_resource} configured application pool")
    else
      Chef::Log.debug("#{new_resource} application pool - nothing to do")
    end
  else
    log "Failed to run iis_pool action :config, #{cmd_current_values.stderr}" do
      level :warn
    end
  end

  @was_updated
end

private

def configure_application_pool(condition, config, add_remove = '')
  return unless condition

  @was_updated = true
  @cmd << " \"/#{add_remove}[name='#{new_resource.pool_name}'].#{config}\""
end
