require_dependency 'clouds/cloud_facade_factory'
require_dependency 'plgrid/pl_grid_facade_factory'

require_relative 'private_machine_facade'

class InfrastructureFacadeFactory

  def self.get_facade_for(infrastructure_name)
    raise InfrastructureErrors::NoSuchInfrastructureError.new(infrastructure_name) if infrastructure_name.nil?
    infrastructure_name = infrastructure_name.to_s

    facade =
        if PlGridFacadeFactory.instance.provider_names.include? infrastructure_name
          PlGridFacadeFactory.instance.get_facade(infrastructure_name)
        elsif CloudFacadeFactory.instance.provider_names.include? infrastructure_name
          CloudFacadeFactory.instance.get_facade(infrastructure_name)
        # elsif infrastructure_name == 'plgrid'
        #   # this is a hack for removing/adding credentials
        #   # because every PL-Grid queuing system uses the same credentials, default Q-system is used
        #   PlGridFacadeFactory.instance.get_facade('qsub')
        else
          facade_class = InfrastructureFacadeFactory.other_infrastructures[infrastructure_name]
          raise InfrastructureErrors::NoSuchInfrastructureError.new(infrastructure_name) if facade_class.nil?
          facade_class.new
        end

    raise InfrastructureErrors::NoSuchInfrastructureError.new(infrastructure_name) if facade.nil?
    facade
  end

  # returns a list of all supported infrastructure ids (short names)
  def self.get_registered_infrastructure_names
    names = other_infrastructures.keys +
      PlGridFacadeFactory.instance.provider_names +
      CloudFacadeFactory.instance.provider_names
    names.map &:to_s
  end

  def self.get_all_infrastructures
    InfrastructureFacadeFactory.get_registered_infrastructure_names.map do |name|
      InfrastructureFacadeFactory.get_facade_for(name)
    end
  end

  # Get JSON data for build a base tree for Infrastructure Tree _without_ Simulation Manager
  # nodes. Starting with non-cloud infrastructures and cloud infrastructures, leaf nodes
  # are fetched recursivety with tree_node methods of every concrete facade.
  def self.list_infrastructures(user_id)
    [
        *(InfrastructureFacadeFactory.other_infrastructures.values.map do |facade_class|
          facade_class.new.to_h(user_id)
        end),
        {
            name: I18n.t('infrastructures_controller.tree.plgrid'),
            group: 'plgrid',
            children:
                PlGridFacadeFactory.instance.provider_names.map do |name|
                  PlGridFacadeFactory.instance.get_facade(name).to_h(user_id).merge(group: 'plgrid')
                end
        },
        {
            name: I18n.t('infrastructures_controller.tree.clouds'),
            group: 'cloud',
            children:
                CloudFacadeFactory.instance.provider_names.map do |name|
                  CloudFacadeFactory.instance.get_facade(name).to_h(user_id).merge(group: 'cloud')
                end
        }
    ]
  end

  def self.start_all_monitoring_threads
    get_all_infrastructures.each do |facade|
      Rails.logger.info("Starting monitoring thread of '#{facade.long_name}'")

      Thread.start do
        facade.monitoring_thread
      end
    end
  end

  def self.get_group_for(infrastructure_name)
    if PlGridFacadeFactory.instance.provider_names.include? infrastructure_name
      'plgrid'
    elsif CloudFacadeFactory.instance.provider_names.include? infrastructure_name
      'cloud'
    else
      nil
    end
  end

  private # ---------------- ----- --- --- -- -- -- - - -


  if Rails.env.development? or Rails.env.test?
    def self.other_infrastructures
      require_relative 'dummy_facade'
      self._other_infrastructures.merge('dummy' => DummyFacade)
    end
  else
    def self.other_infrastructures
      self._other_infrastructures
    end
  end

  def self._other_infrastructures
    {
        'private_machine' => PrivateMachineFacade
    }
  end

end