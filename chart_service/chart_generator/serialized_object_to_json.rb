require "json"
require "base64"

puts JSON.generate(Marshal.load(Base64.decode64(ARGV[0])))
