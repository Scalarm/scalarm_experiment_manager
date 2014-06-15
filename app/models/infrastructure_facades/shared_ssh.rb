# Should be mixin for InfrastructureFacades subclasses
# needs:
# - logger
module SharedSSH
  attr_reader :ssh_sessions

  def initialize(*args)
    super(*args)
    @ssh_sessions = {}
    @mutex = Mutex.new
  end

  def shared_ssh_session(credentials, id=nil)
    @mutex.synchronize do
      # SSH sessions hash can have keys of only credentials_id or (credentials_id + user_defined_id)
      session_id = (id ? "#{credentials.id.to_s}_#{id}" : credentials.id.to_s)
      if @ssh_sessions.include? session_id
        session = @ssh_sessions[session_id]
        if session and not session.closed?
          logger.debug "using existing ssh session: #{session_id}"
          return session
        end
      end

      logger.debug "creating ssh session: #{session_id}"
      @ssh_sessions[session_id] = credentials.ssh_session
    end
  end

  def close_all_ssh_sessions
    @mutex.synchronize do
      logger.debug "closing #{@ssh_sessions.count} ssh sessions" if @ssh_sessions.count > 0
      @ssh_sessions.values.map &:close
      @ssh_sessions = {}
    end
  end

end