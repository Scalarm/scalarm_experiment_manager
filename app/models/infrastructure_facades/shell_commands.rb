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

  def run_in_background(command, stdout='/dev/null', stderr='&1')
    "nohup #{command} >#{stdout} 2>#{stderr} & echo $!"
  end
end
