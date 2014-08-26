require "json"
require "base64"
require "cgi"

puts JSON.generate(Marshal.load(Base64.decode64(CGI::unescape(ARGV[0]))))
