# Should be mixin for InfrastructureFacades subclasses
# needs:
# - logger
module SharedSSH
  attr_reader :ssh_sessions

  def initialize(*args)
    super(*args)
    @ssh_sessions = {}
  end

  def shared_ssh_session(credentials)
    if @ssh_sessions.include? credentials.id
      session = @ssh_sessions[credentials.id]
      if session and not session.closed?
        logger.debug 'using existing ssh session'
        return session
      end
    end

    logger.debug 'creating ssh session'
    @ssh_sessions[credentials.id] = credentials.ssh_session
  end

  def close_all_ssh_sessions
    logger.debug "closing #{@ssh_sessions.count} ssh sessions" if @ssh_sessions.count > 0
    @ssh_sessions.values.map &:close
    @ssh_sessions = {}
  end

end