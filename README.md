Scalarm Experiment Manager
==========================

It provides the main GUI of the Scalarm platform, which enables users to conduct data farming experiment based on
the following workflow:

  * input parameter space definition,
  * simulations execution (scheduling workers onto Clouds, Grids, etc.)
  * monitoring the experiment progress and extending the initial parameter space if necessary,
  * analyse results of the finished simulations.

To run the services you need to fulfill the following requirements:

* Ruby version

We are currently working with Rubinius 2.2.1 installed via RVM.

* System dependencies

Any dependency required by native gems.


* Configuration

You need two configuration files in the config folder.
In the first file, 'scalarm.yml', you put the following information in the YAML format:

```
# at which port the service should listen
information_service_url: localhost:11300
information_service_user: secret_user
information_service_pass: secret_password
# mongo_activerecord config
db_name: 'scalarm_db'
```

The second file, 'puma.rb', is a standard configuration file for the Puma server:
```
environment 'development'
daemonize

#bind 'unix:///tmp/scalarm_experiment_manager.sock'
bind 'tcp://0.0.0.0:3000'

stdout_redirect 'log/puma.log', 'log/puma.log.err', true
pidfile 'puma.pid'

threads 1,16
```

Note: you have to start Storage Manager and Information Service first.

* Experiment Manager service is started/stopped with the following commands:

```
$ rake service:start
$ rake service:stop
```

Note: when deploying on the production environment you need to build assets:

```
$ RAILS_ENV=production rake log_bank:non_digested
```