environment 'development'
daemonize

bind 'unix:///tmp/scalarm_experiment_manager.sock'
#bind 'tcp://0.0.0.0:3000'

#activate_control_app 'tcp://0.0.0.0:4000', { no_token: true }
stdout_redirect 'log/puma.log', 'log/puma.log.err', true
pidfile 'puma.pid'

threads 1,16
