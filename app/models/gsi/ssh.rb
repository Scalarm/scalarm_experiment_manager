require 'gsi'

module Gsi
  module SSH

    class Session

      require 'open3'

      def initialize(host, user, proxy)
        begin
          @host = host
          @user = user
          @proxy = proxy

          @proxy_path = "/tmp/proxy-#{SecureRandom.uuid}"
          File.open(@proxy_path, 'w') { |file| file.write(proxy) }
          File.chmod(0600, @proxy_path)
          @input, @output, @thread =
              Open3.popen2e({'X509_USER_PROXY' => @proxy_path}, 'gsissh', '-v', '-T', "#{user}@#{host}")
          @leftovers = []
          output_results = nil
          # whole process of read should be also timed-out because of single byte timeout
          Timeout.timeout(10) do
            output_results = self.class.time_limited_io_read(@output, 5)
          end
          raise Gsi::ClientError.new('time_limited_io_read failed') if output_results.nil?
          init_log, read_error = output_results
          if read_error == :timeout_error
            raise TimeoutError.new("gsissh invocation timeout, output: #{init_log or '<empty>'}")
          end
          init_match = init_log.match /Entering interactive session./
          Gsi.handle_init_error(init_log) unless init_match
        rescue => e
          Rails.logger.error("Error occurred during GSI session initialization: #{e}")
          close
          raise
        end
      end

      # Reads an {IO} object with {IO.readpartial} one-by-one byte.
      # If reading single byte will exceed time_limit seconds,
      # it will stop and return read string.
      # @param [IO] io IO object to read string from
      # @param [Integer] time_limit max time in seconds to read single byte from IO
      # @return [Array(String, Symbol)]
      #   +[<read string output>, <symbol representing an error or nil>]+
      #   An error can be:
      #   * :timeout - when Timeout::Error occurs because of single char read time limit
      #   * :eof - when EOFError occurs - in most cases this is desired behaviour
      #   * nil - when reading has been stopped because of empty buffer
      def self.time_limited_io_read(io, time_limit = 1)
        buf = ''
        error = nil
        loop do
          begin
            Timeout.timeout(time_limit) do
              buf += io.readpartial(1)
              break unless buf
            end
          rescue Timeout::Error
            error = :timeout
            break
          rescue EOFError
            error = :eof
            break
          end
        end
        [buf, error]
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

      # Kill gsissh process with kill -9
      # The same as Gsi::SSH::Session#close because it uses KILL
      def shutdown!
        close
      end

      def pop_leftovers
        to_pop = @leftovers
        @leftovers = []
        to_pop
      end

      def scp(&block)
        Gsi::SCP.start(@host, @user, @proxy) do |scp|
          yield scp
        end
      end


      # Adding timeout for exec!
      prepend SSHExecTimeout

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