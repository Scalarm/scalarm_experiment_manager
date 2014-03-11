require 'mongo_active_record'

unless Rails.env.test?

  # class initizalization
  config = YAML.load_file(File.join(Rails.root, 'config', 'scalarm.yml'))

  slog('mongo_active_record', "Connecting to 'localhost'")

  unless MongoActiveRecord.connection_init('localhost', config['db_name'])
    information_service = InformationService.new(config['information_service_url'],
                                                 config['information_service_user'],
                                                 config['information_service_pass'])
    storage_manager_list = information_service.get_list_of('db_routers')

    unless storage_manager_list.blank?
    db_router_url = storage_manager_list.sample
      slog('mongo_active_record', "Connecting to '#{db_router_url}'")
    MongoActiveRecord.connection_init(db_router_url, config['db_name'])
    end
  end
end