# Subclasses should implement:
# - _get_ssh_session - return ssh session object
module SSHEnabledRecord
  def self.create_session_method(session_type)
    define_method "#{session_type}_session" do |options={}, &block|
      session = self.send("_get_#{session_type}_session")

      begin
        if block
          begin
            block.call(session)
          ensure
            # SCP has underlying "session"
            if session.respond_to? :session
              session.session.close unless session.session.closed?
            else
              session.close unless session.closed?
            end
          end
        else
          session
        end
      rescue Net::SCP::Error => e
        raise unless options[:ignore_errors]
        Rails.logger.warn("SCP ignored error: #{e.class.to_s} #{e.to_s}")
      end
    end
  end

  create_session_method('ssh')
  create_session_method('scp')

  def upload_file(local_path, remote_path='.', options={})
    scp_session do |scp|
      scp.upload! local_path, remote_path, options
    end
  end
end
