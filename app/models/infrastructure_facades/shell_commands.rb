module ShellCommands
  def chain(*commands)
    commands.join(';')
  end

  def mute(command)
    "#{command} >/dev/null 2>&1"
  end

  def cd(dir)
    "cd #{dir}"
  end

  def rm(file, rf=false)
    "rm #{rf ? '-rf' : ''} #{file}"
  end

  def kill(pid, signal=9)
    "kill -#{signal} #{pid}"
  end

  def echo(s)
    "echo #{s}"
  end

  def tail(path, num_lines)
    "tail -#{num_lines} #{path}"
  end

  def run_and_get_pid(command, stdout='/dev/null', stderr='&1')
    "#{command} >#{stdout} 2>#{stderr} & echo $! 2>/dev/null"
  end

  def run_in_background(command, stdout='/dev/null', stderr='&1')
    "nohup #{run_and_get_pid(command, stdout, stderr)}"
  end

  def run_and_get_exitcode(command, stdout='/dev/null', stderr='&1')
    "#{command} >#{stdout} 2>#{stderr}; echo $?"
  end
end
