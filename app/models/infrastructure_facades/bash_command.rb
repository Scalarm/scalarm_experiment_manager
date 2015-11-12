class BashCommand
  attr_reader :commands

  def initialize
    @commands = []
  end

  def to_s
    "/bin/bash -i -c '#{@commands.join(';')}'"
  end

  def to_raw_s
    @commands.join(';')
  end

  def append(command)
    if command.instance_of?(BashCommand)
      @commands += command.commands
    else
      @commands << command
    end

    self
  end

  def mute(command)
    log command, '/dev/null'
  end

  def cd(dir)
    append "cd #{dir}"
  end

  def log_last_command(stdout, stderr='&1')
    last_cmd = @commands.pop
    log(last_cmd, stdout, stderr)
  end

  def mute_last_command
    last_cmd = @commands.pop
    mute last_cmd
  end

  def log(command, stdout, stderr='&1')
    append "#{command} >#{stdout} 2>#{stderr}"
  end

  def run_and_get_pid(command, stdout='/dev/null', stderr='&1')
    append "#{command} >#{stdout} 2>#{stderr} & echo $! 2>"
  end

  def run_in_background(command, stdout='/dev/null', stderr='&1')
    run_and_get_pid(command, stdout, stderr)
    last_cmd = @commands.pop
    append "nohup #{last_cmd}"
  end

  def run_and_get_pid(command, stdout='/dev/null', stderr='&1')
    append "#{command} >#{stdout} 2>#{stderr} & echo $! 2>/dev/null"
  end

  def run_in_background(command, stdout='/dev/null', stderr='&1')
    run_and_get_pid(command, stdout, stderr)
    last_cmd = @commands.pop
    append "nohup #{last_cmd}"
  end

  def rm(file, rf=false)
    append "rm #{rf ? '-rf' : ''} #{file}"
  end

  def kill(pid, signal=9)
    append "kill -#{signal} #{pid}"
  end

  def echo(s)
    append "echo #{s}"
  end

  def tail(path, num_lines)
    append "tail -#{num_lines} #{path}"
  end

  def mkdir(dir_name, parents=true)
    append "mkdir #{parents ? '-p' : ''} #{dir_name}"
  end

end
