source 'http://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 4.1.12'
gem 'racc'

# wrapper for R interpreter
gem 'rinruby'

gem 'bson'
gem 'bson_ext'
gem 'mongo', '~> 1.12'
# Once upon a time, a mongo-session was tested but it turned out to be buggy
# gem 'mongo_session_store-rails4',
#     git: 'git://github.com/kliput/mongo_session_store.git',
#     branch: 'issue-31-mongo_store-deserialization'

# Amazon EC2 connector
gem 'aws-sdk'

# Google Compute Engine connector
gem 'google-api-client'

gem 'rubyzip'
gem 'encryptor'
gem 'net-ssh'
gem 'net-scp'

# Use SCSS for stylesheets
gem 'sass-rails', '~> 4.0.0'

# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 1.3.0'

# Use CoffeeScript for .js.coffee assets and views
gem 'coffee-rails', '~> 4.0.0'

# See https://github.com/sstephenson/execjs#readme for more supported runtimes
gem 'therubyracer', platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'jquery-tmpl-rails'
gem 'haml'
gem 'foundation-rails'
gem 'jit-rails'
gem 'foundation-icons-sass-rails'
gem 'jquery-datatables-rails', git: 'git://github.com/rweng/jquery-datatables-rails.git'
gem 'font-awesome-sass', '4.4'

# Turbolinks makes following links in your web application faster. Read more: https://github.com/rails/turbolinks
# gem 'turbolinks'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'jbuilder', '~> 1.2'

group :doc do
  # bundle exec rake doc:rails generates the API under doc/api.
  gem 'sdoc', require: false
end

# Use unicorn as the app server
gem 'puma'
#gem 'thin'

# Use debugger
# gem 'debugger', group: [:development, :test]
# Rubinius specifics
platforms :rbx do
  gem 'rubysl', '~> 2.0'
  gem 'rubysl-openssl', '2.0.5'
end

gem 'ruby-openid'
gem 'rest-client', '~> 1.8'
gem 'xml-simple'
gem 'vmstat'

gem 'mocha', group: :test
gem 'ci_reporter_minitest', group: :test

gem 'remotipart', '~> 1.0'

gem 'newrelic_rpm'

## for local development - set path to scalarm-database
# gem 'scalarm-database', path: '/home/jliput/Scalarm/scalarm-database'
gem 'scalarm-database', '>= 0.3.3', git: 'git://github.com/Scalarm/scalarm-database.git'

## for local development - set path to scalarm-core
gem 'scalarm-service_core', path: '/Users/dkrol/workspace/scalarm/scalarm-service_core'
# gem 'scalarm-service_core', '~> 1.0', git: 'git://github.com/Scalarm/scalarm-service_core.git'

#oauth2
gem 'signet'
