LOCAL_IP = UDPSocket.open { |s| s.connect('64.233.187.99', 1); s.addr.last }

unless Rails.env.test?
  require 'monitoring_probe'

  config = YAML.load_file(File.join(Rails.root, 'config', 'scalarm.yml'))['monitoring']
  MONITORING_DB = MongoActiveRecord.get_database(config['db_name'])


  monitoring_probe = MonitoringProbe.new
  monitoring_probe.start_monitoring
end
