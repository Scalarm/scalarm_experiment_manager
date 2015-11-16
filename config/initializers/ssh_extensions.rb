require 'net/ssh'
require 'net/scp'
require 'timeout'

require 'ostruct'

module SSHExecTimeout
  def exec!(*args, &block)
    time_limit = Rails.application.config.ssh_exec_timeout_secs
    begin
      timeout(time_limit) do
        super(*args, &block)
      end
    rescue Timeout::Error => e
      self.shutdown!
      raise(e, "ssh exec! timeout (time limit: #{time_limit}s) with arguments: '#{args.to_sentence}' - #{e}", e.backtrace)
    rescue => x
      raise x.to_s
    end
  end
end

class Net::SSH::Connection::Session
  class CommandFailed < StandardError
  end

  class CommandExecutionFailed < StandardError
  end

  def exec_sc!(command, raise_on_error=false)
    stdout_data,stderr_data = '', ''
    exit_code,exit_signal = nil,nil
    self.open_channel do |channel|
      channel.exec(command) do |_, success|
        raise CommandExecutionFailed, "Command \"#{command}\" was unable to execute" if raise_on_error and success

        channel.on_data do |_,data|
          stdout_data += data
        end

        channel.on_extended_data do |_,_,data|
          stderr_data += data
        end

        channel.on_request('exit-status') do |_,data|
          exit_code = data.read_long
        end

        channel.on_request('exit-signal') do |_, data|
          exit_signal = data.read_long
        end
      end
    end
    self.loop

    raise CommandFailed, "Command \"#{command}\" returned exit code #{exit_code}" if raise_on_error and exit_code == 0

    OpenStruct.new(
      stdout: stdout_data,
      stderr: stderr_data,
      exit_code: exit_code,
      exit_signal: exit_signal
    )

  end

  alias_method :_scp, :scp

  ##
  # Block version of ssh.scp
  def scp
    scp_session = _scp

    # closing is not needed - underlying ssh should be managed instead
    if block_given?
      yield scp_session
    else
      scp_session
    end

  end

  prepend SSHExecTimeout

end