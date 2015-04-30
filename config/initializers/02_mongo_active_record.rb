unless Rails.env.test?
  require 'scalarm/database/mongo_active_record'

  # class initizalization
  config = YAML.load_file(File.join(Rails.root, 'config', 'scalarm.yml'))

  slog('mongo_active_record', "Connecting to 'localhost'")

  unless Scalarm::Database::MongoActiveRecord.connection_init('localhost', config['db_name'])
    information_service = InformationService.new
    storage_manager_list = information_service.get_list_of('db_routers')

    unless storage_manager_list.blank?
      db_router_url = storage_manager_list.sample
      slog('mongo_active_record', "Connecting to '#{db_router_url}'")
      Scalarm::Database::MongoActiveRecord.connection_init(db_router_url, config['db_name'])
    end
  end
end