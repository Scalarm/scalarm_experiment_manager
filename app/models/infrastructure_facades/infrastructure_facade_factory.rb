require_dependency 'clouds/cloud_facade_factory'
require_dependency 'plgrid/pl_grid_facade_factory'

require_relative 'private_machine_facade'

class InfrastructureFacadeFactory

  def self.get_facade_for(infrastructure_name)
    raise InfrastructureErrors::NoSuchInfrastructureError.new(infrastructure_name) if infrastructure_name.nil?
    info = get_registered_infrastructures[infrastructure_name.to_sym]
    raise InfrastructureErrors::NoSuchInfrastructureError.new(infrastructure_name) if info.nil? or not info.has_key? :facade
    info[:facade]
  end

  # returns a map of all supported infrastructures
  # infrastructure_id => {label: long_name, facade: facade_instance}
  # TODO: should be unified with list_infrastructures
  def self.get_registered_infrastructures
    other_infrastructures.merge(cloud_infrastructures).merge(pl_grid_infrastructures)
  end

  # Get JSON data for build a base tree for Infrastructure Tree _without_ Simulation Manager
  # nodes. Starting with non-cloud infrastructures and cloud infrastructures, leaf nodes
  # are fetched recursivety with tree_node methods of every concrete facade.
  def self.list_infrastructures
    [
        *(InfrastructureFacadeFactory.other_infrastructures.values.map do |inf|
          inf[:facade].to_h
        end),
        {
            name: I18n.t('infrastructures_controller.tree.plgrid'),
            group: 'plgrid',
            children:
                InfrastructureFacadeFactory.pl_grid_infrastructures.values.map do |inf|
                  inf[:facade].to_h.merge(group: 'plgrid')
                end
        },
        {
            name: I18n.t('infrastructures_controller.tree.clouds'),
            group: 'cloud',
            children:
                InfrastructureFacadeFactory.cloud_infrastructures.values.map do |inf|
                  inf[:facade].to_h.merge(group: 'cloud')
                end
        }
    ]
  end

  def self.start_all_monitoring_threads
    get_registered_infrastructures.each do |infrastructure_id, infrastructure_information|
      Rails.logger.info("Starting monitoring thread of '#{infrastructure_id}'")

      Thread.start do
        infrastructure_information[:facade].monitoring_thread
      end
    end
  end

  private # ---------------- ----- --- --- -- -- -- - - -

  if Rails.env.development? or Rails.env.test?
    def self.other_infrastructures
      require_relative 'dummy_facade'
      self._other_infrastructures.merge(dummy: {label: 'Dummy', facade: DummyFacade.new})
    end
  else
    def self.other_infrastructures
      self._other_infrastructures
    end
  end

  def self.pl_grid_infrastructures
    PlGridFacadeFactory.instance.infrastructures_hash
  end

  def self.cloud_infrastructures
    CloudFacadeFactory.instance.infrastructures_hash
  end

  # TODO: change to classes, because always all facades are initialized; remove "label"
  def self._other_infrastructures
    {
        private_machine: { label: 'Private resources', facade: PrivateMachineFacade.new }
    }
  end

end