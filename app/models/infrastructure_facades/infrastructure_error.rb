module Infrastructure
  class NoCredentialsError < StandardError; end
  class InvalidCredentialsError < StandardError; end
  class CloudError < StandardError; end
end