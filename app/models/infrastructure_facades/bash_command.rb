class BashCommand

  def initialize
    @commands = []
  end

  def to_s
    "/bin/bash -i -c '#{@commands.join(';')}'"
  end

  def append(command)
    @commands << command
    self
  end

  def mute_last_command
    last_cmd = @commands.pop
    append "#{last_cmd} >/dev/null 2>&1"
  end

  def mute(command)
    append "#{command} >/dev/null 2>&1"
  end

  def self.muted(method_symbol)
    define_method "muted_#{method_symbol}".to_sym do |*args|
      send method_symbol, *args
      mute_last_command
    end
  end

  def cd(dir)
    append "cd #{dir}"
  end

  muted :cd

  def rm(file, rf=false)
    append "rm #{rf ? '-rf' : ''} #{file}"
  end

  muted :rm

  def kill(pid, signal=9)
    append "kill -#{signal} #{pid}"
  end

  muted :kill

  def echo(s)
    append "echo #{s}"
  end

  def tail(path, num_lines)
    append "tail -#{num_lines} #{path}"
  end

  def run_and_get_pid(command, stdout='/dev/null', stderr='&1')
    append "#{command} >#{stdout} 2>#{stderr} & echo $! 2>/dev/null"
  end

  def run_in_background(command, stdout='/dev/null', stderr='&1')
    run_and_get_pid(command, stdout, stderr)
    last_cmd = @commands.pop
    append "nohup #{last_cmd}"
  end

  def run_and_get_exitcode(command, stdout='/dev/null', stderr='&1')
    append "#{command} >#{stdout} 2>#{stderr}; echo $?"
  end

end