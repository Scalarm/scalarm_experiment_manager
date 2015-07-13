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

Currently we use and test Scalarm against MRI 2.1.x but the Rubinius version of Ruby should be good as well.

Please install Ruby with RVM as described on http://rvm.io/
```
\curl -sSL https://get.rvm.io | bash -s stable --ruby=2.1
```

Follow installation instructrions and reload shell on the end if necessary.


System dependencies
-------------------

* curl
* R
* gsissh
* sysstat (mpstat/iostat)
* any dependency required by native gems

Optionally you will need also mongos, but it will be fetched automatically if it's not found and if you use "rake db_router:setup".

Some requirements will be installed by rvm also during ruby installation.


### Specific distributions

#### Ubuntu

Add Globus Toolkit repository to enable grid support: http://toolkit.globus.org/ftppub/gt6/installers/repo/globus-toolkit-repo_latest_all.deb

Then use this one-liner to install dependencies:
```
sudo apt-get update && sudo apt-get install curl r-base-core sysstat gsi-openssh-clients
```

#### RedHat/Fedora/ScientificLinux

For SL 6.4 you need to add nginx repo and then install:

```
yum install git vim nginx wget man libxml2 sqlite sqlite-devel R curl sysstat
```


Installation
------------

You can download it directly from GitHub

```
git clone https://github.com/Scalarm/scalarm_experiment_manager
```

After downloading the code you just need to install gem requirements:

```
cd scalarm_experiment_manager
bundle install
```

if any dependency is missing you will be noticed :)

To check if all dependencies are meet, and install Scalarm external modules please use:

```
rake db_router:setup
rake service:setup
```


Configuration
-------------

There are two files with configuration: config/secrets.yml and config/puma.rb.

The "secrets.yml" file is a standard configuration file added in Rails 4 to have a single place for all secrets in
an application. We used this approach in our Scalarm platform. Experiment Manager stores access data to
Information Service in this file:

```
default: &DEFAULT
  ## cookies enctyption key - set the same in each ExperimentManager to allow cooperation
  secret_key_base: "<you need to change this - with $rake secret>"

  ## InformationService - a service locator
  information_service_url: "localhost:11300"
  information_service_user: "<set to custom name describing your Scalarm instance>"
  information_service_pass: "<generate strong password instead of this>"
  ## uncomment, if you want to communicate through HTTP with Scalarm Information Service
  # information_service_development: true

  ## Database configuration
  ## name of MongoDB database, it is scalarm_db by default
  db_name: 'scalarm_db'
  ## key for symmetric encryption of secret database data - please change it in production installations!
  ## NOTICE: this key should be set ONLY ONCE BEFORE first run - if you change or lost it, you will be UNABLE to read encrypted data!
  db_secret_key: "QjqjFK}7|Xw8DDMUP-O$yp"

  ## Uncomment, if you want to communicate through HTTP with Scalarm Storage Manager
  # storage_manager_development: true

  ## Configuration of optional Scalarm LoadBalancer (https://github.com/Scalarm/scalarm_load_balancer)
  load_balancer:
      # if you installed and want to use scalarm custom load balancer set to false
      disable_registration: true
      # if you use load balancer you need to specify multicast address (to receive load balancer address)
      #multicast_address: "224.1.2.3:8000"
      # if you use load balancer on http you need to specify this
      #development: true
      # if you want to run and register service in load balancer on other port than default
      #port: "3000"

  ## Uncomment "anonymous_user" block to create and use default user
  #anonymous_user:
  #    login: 'anonymous'
  #    password: 'anonymous'

  ## Configuration of ExperimentManager machine monitoring, uncomment to enable
  #monitoring:
  #  db_name: 'scalarm_monitoring'
  #  interval: 30
  #  metrics: 'cpu'

  ## CA/certificate path of ExperimentManager server to allow secure communication to it
  ## from other services
  #certificate_path: "/path/to/ca_for_information_service.pem"
  ## If you use HTTPS connections but don't have valid certificates (eg. self-signed)
  #insecure_ssl: true

  ## if you want to communicate with Storage Manager using a different URL than the one stored in Information Service
  #storage_manager_url: "localhost:20000"
  ## if you want to pass to Simulation Manager a different URL of Information Service than the one mentioned above
  #sm_information_service_url: "localhost:37128"

production:
  ## In production environments some settings should not be stored in configuration file
  ## for security reasons.

  secret_key_base: <%= ENV["SECRET_KEY_BASE"] %>
  information_service_url: "<%= ENV["INFORMATION_SERVICE_URL"] %>"
  information_service_user: "<%= ENV["INFORMATION_SERVICE_LOGIN"] %>"
  information_service_pass: "<%= ENV["INFORMATION_SERVICE_PASSWORD"] %>"

development:
  <<: *DEFAULT

test:
  <<: *DEFAULT


```

The example file is placed in config/secrets.yml.example and will be copied to config/secrets.yml if there is no configuration.

In this "config/scalarm.yml" file we have various information Scalarm configuration - typically there is no need to change them:

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
export RAILS_ENV=production
```


```
rake service:start
rake service:stop
```
Please remember to set RAILS_ENV=production when running in the production mode.

Before the first start (in the production mode) of the service you need to compile assets:
```
rake service:non_digested
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
    proxy_set_header X-Forwarded-Proto https; # New header for SSL

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
curl -k -u scalarm:scalarm --data "address=172.16.67.77" https://localhost:11300/experiment_managers
```

When running in a production-like environment set the SECRET_KEY_BASE environment variable to the value generated by:

```
rake secret
```
 
To check if Experiment Manager has been installed correctly just start the service and open a web browser and go the login page:
```sh
firefox https://172.16.67.77
```

Updating
----
Every time you want to update this service, please shut down service with ```rake service:stop``` update git repository with ```git pull``` and get new Scalarm external packages with ```rake service:update```. Then You can start service with ```git service:start```.

Building Scalarm external modules manually (optional)
----
Instead of using precompiled binaries, you can build Scalarm Simulation Manager and Scalarm Monitoring packages.

Needed dependencies:

* git
* go (https://golang.org/dl/)
 * you should build cross compilers for linux 386 and linux amd64: http://stackoverflow.com/questions/12168873/cross-compile-go-on-osx


To fetch codes from git and start build, use:

```
rake build:all
```


License
----

MIT
