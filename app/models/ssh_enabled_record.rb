# Subclasses should implement:
# - _get_ssh_session - return ssh session object
module SSHEnabledRecord
  def self.create_session_method(session_type)
    define_method "#{session_type}_session" do |&block|
      session = self.send("_get_#{session_type}_session")

      if block
        begin
          block.call(session)
        ensure
          session.close unless session.closed?
        end
      else
        session
      end
    end
  end

  create_session_method('ssh')
  create_session_method('scp')

  def upload_file(local_path, remote_path='.')
    scp_session do |scp|
      scp.upload! local_path, remote_path
    end
  end
end
