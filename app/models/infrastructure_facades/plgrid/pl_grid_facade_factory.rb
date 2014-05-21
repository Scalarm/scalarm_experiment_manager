require 'singleton'

class PlGridFacadeFactory < DependencyInjectionFactory
  include Singleton

  def initialize
    super(
        File.join(Rails.root, 'app/models/infrastructure_facades/plgrid/grid_schedulers'),
        'PlGridScheduler',
        PlGridFacade
    )
  end

end