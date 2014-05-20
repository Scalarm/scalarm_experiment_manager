unless Rails.env.test?
# job1 = fork {
	# Start experiment watcher
	ExperimentWatcher.watch_experiments
	# sleep(10) while true
# }
# Process.detach(job1)

# job2 = fork {
	# Start infrastructure Monitoring
	InfrastructureFacadeFactory.start_all_monitoring_threads
	# sleep(10) while true
# }
# Process.detach(job2)
end