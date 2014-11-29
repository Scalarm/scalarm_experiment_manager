require 'net/scp'

module Net
  module SCPExtensions

    def upload!(local, remote, options={}, &progress)
      begin
        super(local, remote, options, &progress)
      rescue Net::SCP::Error => e
        raise unless options[:ignore_errors]
        Rails.logger.warn("SCP ignored error: #{e.class.to_s} #{e.to_s}")
      end
    end

    def upload_multiple!(local_paths, *other_args)
      local_paths.each do |path|
        self.upload! path, *other_args
      end
    end

  end

  class SCP
    prepend SCPExtensions
  end
end