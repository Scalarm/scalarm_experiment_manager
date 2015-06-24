require 'gsi'

module Gsi
  module SCP
    class Session
      def initialize(host, user, proxy)
        @host = host
        @user = user

        @proxy_path = "/tmp/proxy-#{SecureRandom.uuid}"
        File.open(@proxy_path, 'w') { |file| file.write(proxy) }
        File.chmod(0600, @proxy_path)

        @closed = false
      end

      def upload_multiple!(local_paths, remote_path='.')
        upload! local_paths, remote_path
      end

      # @param [String, Array<String>] local_path
      #   In this implementation, both #upload! and #upload_multiple!
      #     can take String or Array of String
      def upload!(local_path, remote_path='.')
        _invoke_command local_path, "#{@user}@#{@host}:#{remote_path}"
      end

      def closed?
        @closed
      end

      def close
        @closed = true
        FileUtils.rm @proxy_path, force: true
      end

      private # ---

      def _invoke_command(left, right)
        out, status = Open3.capture2e({'X509_USER_PROXY' => @proxy_path}, 'gsiscp', '-v', *left, *right)
        unless status.success?
          Gsi.handle_init_error(out)
        end
      end
    end

    def self.start(host, user, proxy, options={}, &block)
      session = Gsi::SCP::Session.new(host, user, proxy)
      if block_given?
        begin
          yield session
        ensure
          session.close unless session.closed?
        end
      else
        return session
      end
    end
  end
end