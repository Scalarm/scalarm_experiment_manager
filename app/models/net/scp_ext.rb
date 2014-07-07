require 'net/scp_ext'

module Net
  class SCP
    def upload_multiple!(local_paths, *other_args)
      local_paths.each do |path|
        self.upload! path, *other_args
      end
    end
  end
end