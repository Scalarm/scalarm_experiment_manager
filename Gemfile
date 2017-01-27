source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '~> 4.2.6'
gem 'racc'

# wrapper for R interpreter
gem 'rinruby'

# Amazon EC2 connector
gem 'aws-sdk'

# Google Compute Engine connector
gem 'google-api-client', '~> 0.7.1'

gem 'rubyzip', require: 'zip'
gem 'zip-zip'
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
# force libv8 version, which can be build separately in OSX
gem 'libv8', '3.16.14.13'
gem 'therubyracer', '0.12.1', platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'
gem 'jquery-ui-rails'
gem 'jquery-tmpl-rails'
gem 'haml'
gem 'foundation-rails', '5.4.5'
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
gem 'xml-simple', '1.1.3'
gem 'vmstat'

gem 'mocha', group: :test
gem 'ci_reporter_minitest', group: :test

gem 'remotipart', '~> 1.0'

gem 'newrelic_rpm'

## for local development - set path to scalarm-database
# gem 'scalarm-database', path: '/vagrant/scalarm-database'
gem 'scalarm-database', '~> 2.0.0', git: 'git://github.com/Scalarm/scalarm-database.git'

## for local development - set path to scalarm-core
# gem 'scalarm-service_core', path: '/vagrant/scalarm-service_core'
gem 'scalarm-service_core', '~> 2.0.0', git: 'git://github.com/Scalarm/scalarm-service_core.git'

#oauth2
gem 'signet'

gem 'sidekiq'
gem 'sinatra', :require => nil

gem 'pry-rails'
gem 'awesome_print'

group :development do
  gem "better_errors"
  gem "binding_of_caller"
end

gem 'method_source'

gem 'mongoid', '~> 5.1.0'
