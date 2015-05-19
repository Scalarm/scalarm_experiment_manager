unless Rails.env.test?
  require 'scalarm/database/core/mongo_active_record'

  # class initizalization
  config = YAML.load_file(File.join(Rails.root, 'config', 'scalarm.yml'))

  db_key = Digest::SHA256.hexdigest(Rails.application.secrets.db_secret_key || 'QjqjFK}7|Xw8DDMUP-O$yp')
  Scalarm::Database::MongoActiveRecord.set_encryption_key(db_key)

  Scalarm::Database::Logger.register(Rails.logger)

  # by default, try to connect to local mongodb
  # TODO: connect to local mongodb only if list of db_routers is empty
  slog('mongo_active_record', 'Trying to connect to localhost')
  if Scalarm::Database::MongoActiveRecord.connection_init('localhost', config['db_name'])

  else
    slog('mongo_active_record', 'Cannot connect to local mongodb - fetching mongodb adresses from IS')
    information_service = InformationService.new
    storage_manager_list = information_service.get_list_of('db_routers')

    if storage_manager_list.blank?
      slog('init', 'Error: db_routers list from IS is empty - there is no database to connect')
      raise 'db_routers list from IS is empty'
    else
      slog('init', "Fetched db_routers list: #{storage_manager_list}")
      db_router_url = storage_manager_list.sample
      slog('mongo_active_record', "Connecting to '#{db_router_url}'")
      Scalarm::Database::MongoActiveRecord.connection_init(db_router_url, config['db_name'])
    end
  end
end