require 'gsi'

module Gsi
  module SSH

    class Session

      require 'open3'

      def initialize(host, user, proxy)
        begin
          @proxy_path = "/tmp/proxy-#{SecureRandom.uuid}"
          File.open(@proxy_path, 'w') { |file| file.write(proxy) }
          File.chmod(0600, @proxy_path)
          @input, @output, @thread =
              Open3.popen2e({'X509_USER_PROXY' => @proxy_path}, 'gsissh', '-v', '-T', "#{user}@#{host}")
          @leftovers = []
          init_log = ''
          begin
            Timeout::timeout 5 do
              init_log = @output.readline 'Entering interactive session.'
            end
          rescue Timeout::Error, Errno::EPIPE
            raise TimeoutError.new("gsissh invocation timeout, output: #{@output.read}")
          end
          init_match = init_log.match /Entering interactive session./
          Gsi.handle_init_error(init_log) unless init_match
        rescue Exception
          close
          raise
        end
      end

      def exec!(command)
        cmd_id = Random.rand(1024)
        start_separator = "!CMD_START_#{cmd_id}!"
        end_separator = "!CMD_END_#{cmd_id}!"
        send_data "echo '#{start_separator}'; (#{command}) 2>&1; echo '#{end_separator}'"
        cmd_output = @output.readline end_separator + "\n"
        match = cmd_output.match(/(.*)#{start_separator}\n(.*)#{end_separator}\n(.*)/m)
        if match
          @leftovers << match[1] if match[1] and match[1] != ''
          match[2]
        else
          raise StandardError.new("Wrong command output: #{cmd_output}")
        end
      end

      # Sends data via stdin to ssh process
      def send_data(data)
        @input.puts data
      end

      def closed?
        not @thread.status and @input.closed? and @output.closed?
      end

      def close
        begin
          Process.kill 'KILL', @thread.pid rescue Errno::ESRCH
        ensure
          @input.close unless @input.closed?
          @output.close unless @output.closed?
          FileUtils.rm @proxy_path, force: true
        end
      end

      def pop_leftovers
        to_pop = @leftovers
        @leftovers = []
        to_pop
      end
    end

    def self.start(host, user, proxy_cert_path, options={}, &block)
      connection = Gsi::SSH::Session.new(host, user, proxy_cert_path)
      if block_given?
        begin
          yield connection
        ensure
          connection.close unless connection.closed?
        end
      else
        return connection
      end
    end

  end

end