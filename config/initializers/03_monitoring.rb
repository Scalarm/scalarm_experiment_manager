unless Rails.env.test?
  require 'monitoring_probe'

  monitoring_probe = MonitoringProbe.new
  monitoring_probe.start_monitoring
end
