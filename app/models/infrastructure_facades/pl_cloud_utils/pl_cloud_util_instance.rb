# This file includes VM states constants from OpenNebula project:
# https://github.com/OpenNebula/one
# Copyright 2002-2013, OpenNebula Project (OpenNebula.org), C12G Labs
# Licensed under the Apache License, Version 2.0

# Util class, which instance can be created either with initializer
# or PLCloudClient.vm_instance method.
# User can obtain information and perform some tasks on VM which id
# is equal to vm_id attribute of this class.
class PLCloudUtilInstance

    # see: https://github.com/OpenNebula/one/blob/master/include/VirtualMachine.h

  VM_STATES = {
      0 => 'INIT',
      1 => 'PENDING',
      2 => 'HOLD',
      3 => 'ACTIVE',
      4 => 'STOPPED',
      5 => 'SUSPENDED',
      6 => 'DONE',
      7 => 'FAILED',
      8 => 'POWEROFF',
      9 => 'UNDEPLOYED'
  }

  LCM_STATES = {
      0 => 'LCM_INIT',
      1 => 'PROLOG',
      2 => 'BOOT',
      3 => 'RUNNING',
      4 => 'MIGRATE',
      5 => 'SAVE_STOP',
      6 => 'SAVE_SUSPEND',
      7 => 'SAVE_MIGRATE',
      8 => 'PROLOG_MIGRATE',
      9 => 'PROLOG_RESUME',
      10 => 'EPILOG_STOP',
      11 => 'EPILOG',
      12 => 'SHUTDOWN',
      13 => 'CANCEL',
      14 => 'FAILURE',
      15 => 'CLEANUP_RESUBMIT',
      16 => 'UNKNOWN',
      17 => 'HOTPLUG',
      18 => 'SHUTDOWN_POWEROFF',
      19 => 'BOOT_UNKNOWN',
      20 => 'BOOT_POWEROFF',
      21 => 'BOOT_SUSPENDED',
      22 => 'BOOT_STOPPED',
      23 => 'CLEANUP_DELETE',
      24 => 'HOTPLUG_SNAPSHOT',
      25 => 'HOTPLUG_NIC',
      26 => 'HOTPLUG_SAVEAS',
      27 => 'HOTPLUG_SAVEAS_POWEROFF',
      28 => 'HOTPLUG_SAVEAS_SUSPENDED',
      29 => 'SHUTDOWN_UNDEPLOY',
      30 => 'EPILOG_UNDEPLOY',
      31 => 'PROLOG_UNDEPLOY',
      32 => 'BOOT_UNDEPLOY'
  }

  # see: https://github.com/OpenNebula/one/blob/master/src/oca/ruby/opennebula/virtual_machine.rb

  SHORT_VM_STATES={
      "INIT"      => "init",
      "PENDING"   => "pend",
      "HOLD"      => "hold",
      "ACTIVE"    => "actv",
      "STOPPED"   => "stop",
      "SUSPENDED" => "susp",
      "DONE"      => "done",
      "FAILED"    => "fail",
      "POWEROFF"  => "poff",
      "UNDEPLOYED"=> "unde"
  }

  SHORT_LCM_STATES={
      "PROLOG"            => "prol",
      "BOOT"              => "boot",
      "RUNNING"           => "runn",
      "MIGRATE"           => "migr",
      "SAVE_STOP"         => "save",
      "SAVE_SUSPEND"      => "save",
      "SAVE_MIGRATE"      => "save",
      "PROLOG_MIGRATE"    => "migr",
      "PROLOG_RESUME"     => "prol",
      "EPILOG_STOP"       => "epil",
      "EPILOG"            => "epil",
      "SHUTDOWN"          => "shut",
      "CANCEL"            => "shut",
      "FAILURE"           => "fail",
      "CLEANUP_RESUBMIT"  => "clea",
      "UNKNOWN"           => "unkn",
      "HOTPLUG"           => "hotp",
      "SHUTDOWN_POWEROFF" => "shut",
      "BOOT_UNKNOWN"      => "boot",
      "BOOT_POWEROFF"     => "boot",
      "BOOT_SUSPENDED"    => "boot",
      "BOOT_STOPPED"      => "boot",
      "CLEANUP_DELETE"    => "clea",
      "HOTPLUG_SNAPSHOT"  => "snap",
      "HOTPLUG_NIC"       => "hotp",
      "HOTPLUG_SAVEAS"           => "hotp",
      "HOTPLUG_SAVEAS_POWEROFF"  => "hotp",
      "HOTPLUG_SAVEAS_SUSPENDED" => "hotp",
      "SHUTDOWN_UNDEPLOY" => "shut",
      "EPILOG_UNDEPLOY"   => "epil",
      "PROLOG_UNDEPLOY"   => "prol",
      "BOOT_UNDEPLOY"     => "boot"
  }

  attr_reader :vm_id
  attr_reader :info

  # @param [Fixnum] vm_id
  # @param [PLCloudUtil] plc_client
  def initialize(vm_id, plc_client)
    @vm_id = vm_id
    @plc_client = plc_client
    @info = plc_client.vm_info(vm_id)
  end

  # Check if VM instance exists on VM's list.
  def exists?
    @plc_client.all_vm_info.has_key? @vm_id
  end

  def refresh_info
    @info = @plc_client.vm_info(@vm_id)
  end

  # Using VmState mapped to SHORT_VM_STATES, see:
  # core: https://github.com/OpenNebula/one/blob/master/include/VirtualMachine.h
  # ruby: https://github.com/OpenNebula/one/blob/master/src/oca/ruby/opennebula/virtual_machine.rb
  #
  # @return [String] VM's State - one of SHORT_VM_STATES
  def short_vm_state
    refresh_info
    SHORT_VM_STATES[VM_STATES[@info['STATE'].to_i]]
  end

  # Using VmState mapped to SHORT_LCM_STATES, see:
  # core: https://github.com/OpenNebula/one/blob/master/include/VirtualMachine.h
  # ruby: https://github.com/OpenNebula/one/blob/master/src/oca/ruby/opennebula/virtual_machine.rb
  #
  # @return [String] VM's Life Cycle Manager State - one of SHORT_LCM_STATES
  def short_lcm_state
    refresh_info
    SHORT_LCM_STATES[LCM_STATES[@info['LCM_STATE'].to_i]]
  end

  # @return [Fixnum] image id
  def image_id
    @info['TEMPLATE']['DISK']['IMAGE_ID'].to_i
  end

  def private_ip
    @info['TEMPLATE']['NIC']['IP']
  end

  def redirections
    @plc_client.redirections_for(private_ip)
  end

  def redirect_port(port)
    @plc_client.redirect_port(private_ip, port)
  end

  # Terminates and deletes this VM instance - use with caution!
  def delete
    @plc_client.delete_instance(@vm_id)
  end

  # Reboots VM. It is equivalent to 'reboot' command in VM's console.
  def reboot
    @plc_client.execute('onevm', ['reboot', @vm_id])
  end

  def resubmit

  end

end