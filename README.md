![Scalarm Logo](http://scalarm.com/images/scalarmNiebieskiemale.png)

Scalarm Experiment Manager
==========================

Experiment Manager is the main component of the Scalarm platform. It provides core functionalities and User Interfaces
necessary to conduct data farming experiments according to the following workflow:
  * input parameter space definition,
  * simulations execution (scheduling workers onto Clouds, Grids, etc.)
  * monitoring the experiment progress and extending the initial parameter space if necessary,
  * analyse results of the finished simulations.

To run the services you need to fulfill the following requirements:

Ruby version
------------

Currently we use and test Scalarm against MRI 2.1.1 but the Rubinius version of Ruby should be good as well.

```
$ sudo curl -L https://get.rvm.io | bash
```

Agree on anything they ask :)

```
$ source $HOME/.rvm/scripts/rvm
$ rvm install 2.1.1
```

Also agree on anything. After the last command, rubinius version of ruby will be downloaded and installed from source.


System dependencies
-------------------

For SL 6.4 you need to add nginx repo and then install:

```
$ yum install git vim nginx wget man libxml2 sqlite sqlite-devel R curl sysstat
```

Some requirements will be installed by rvm also during ruby installation.

Any dependency required by native gems.

Installation
------------

You can download it directly from GitHub

```
$ git clone https://github.com/Scalarm/scalarm_experiment_manager
```

After downloading the code you just need to install gem requirements:

```
$ cd scalarm_experiment_manager
$ bundle install
```

if any dependency is missing you will be noticed :)

Configuration
-------------

There are three files with configuration: config/secrets.yml, config/scalarm.yml and config/puma.rb.

The "secrets.yml" file is a standard configuration file added in Rails 4 to have a single place for all secrets in
an application. We used this approach in our Scalarm platform. Experiment Manager stores access data to
Information Service in this file:

```
development:
  secret_key_base: 'd132fd22bc612e157d722e980c4b0525b938f225f9f7f66ea'
  information_service_url: "localhost:11300"
  information_service_user: scalarm
  information_service_pass: scalarm
  # if you want to communicate through HTTP
  information_service_development: true

test:
  secret_key_base: 'd132fd22bc612e157d722e980c4b0525b938f225f9f7f66ea'
  information_service_url: "localhost:11300"
  information_service_user: scalarm
  information_service_pass: scalarm
  # if you want to communicate through HTTP
  information_service_development: true

production:
  secret_key_base: <%= ENV["SECRET_KEY_BASE"] %>
  information_service_url: "localhost:11300"
  information_service_user: "<%= ENV["INFORMATION_SERVICE_LOGIN"] %>"
  information_service_pass: "<%= ENV["INFORMATION_SERVICE_LOGIN"] %>"
```

In this "config/scalarm.yml" file we have various information Scalarm configuration - typically there is no need to change them:

```
# mongo_activerecord config
db_name: 'scalarm_db'

monitoring:
  db_name: 'scalarm_monitoring'
  metrics: 'cpu:memory:storage'
```

In the "config/puma.rb" configuration of the PUMA web server is stored:

```
environment 'production'

bind 'unix:///tmp/scalarm_experiment_manager.sock'

threads 1,8

daemonize
pidfile 'puma.pid'
stdout_redirect 'log/puma.log', 'log/puma.log.err', true
```

To start/stop the service you can use the provided Rakefile:
```
$ rake service:start
$ rake service:stop
```
Please remember to set RAILS_ENV=production when running in the production mode.

Before the first start (in the production mode) of the service you need to compile assets:
```
$ rake service:non_digested
```
 
With the configuration as above Experiment Manager will be listening on linux socket. To make it available for other services we will use a HTTP server - nginx - which will also handle SSL.

To configure NGINX you basically need to add some information to NGINX configuration, e.g. in the /etc/nginx/conf.d/default.conf file.

```
# ================ SCALARM EXPERIMENT MANAGERS
upstream scalarm_experiment_manager {
  server unix:/tmp/scalarm_experiment_manager.sock;
}

server {
  listen 443 ssl default_server;
  client_max_body_size 0;

  ssl_certificate /etc/nginx/server.crt;
  ssl_certificate_key /etc/nginx/server.key;

  ssl_verify_client optional;
  ssl_client_certificate /etc/grid-security/certificates/PolishGrid.pem;
  ssl_verify_depth 5;
  ssl_session_timeout 30m;

  location / {
    proxy_pass http://scalarm_experiment_manager;

    proxy_set_header SSL_CLIENT_S_DN $ssl_client_s_dn;
    proxy_set_header SSL_CLIENT_I_DN $ssl_client_i_dn;
    proxy_set_header SSL_CLIENT_VERIFY $ssl_client_verify;
    proxy_set_header SSL_CLIENT_CERT $ssl_client_cert;
    proxy_set_header X-Real-IP  $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header Host $http_host;

    break;
  }
}
# it is also needed to force HTTPS
server {
  listen 80;
  return 301 https://$host$request_uri;
}
```

One last thing to do is to register Experiment Manager in the Scalarm Information Service. With the presented configuration (and assuming we are working on a hypothetical IP address 172.16.67.77) we just need to:
```
$ curl -k -u scalarm:scalarm --data "address=172.16.67.77" https://localhost:11300/experiment_manager
```

When running in a production-like environment set the SECRET_KEY_BASE environment variable to the value generated by:

```
$ rake secret
```
 
To check if Experiment Manager has been installed correctly just start the service and open a web browser and go the login page:
```sh
firefox https://172.16.67.77
```

License
----

MIT
