SimulationManager::Application.routes.draw do
  match "simulations" => "simulations#index"
  get "simulations/index"
  get "simulations/registration"
  post "simulations/upload_component"
  post "simulations/destroy_component"
  post "simulations/upload_simulation"
  post "simulations/destroy_simulation"
  post "simulations/conduct_experiment"


  get "user_controller/login"
  match "login" => "user_controller#login"
  post "user_controller/login"
  get "user_controller/logout"
  post "user_controller/logout"
  match "login" => "user_controller#logout"

  get "configuration/managers"
  get "configuration/storage_managers"
  post "configuration/log_failure"
  get "configuration/log_failure"

  #experiment-related routes
  post "experiments/start"
  post "experiments/define_param_types"
  post "experiments/define_input"
  post "experiments/define_doe"
  post "experiments/run"
  post "experiments/stop"
  post "experiments/destroy"
  get "experiments/monitor"
  get "experiments/latest_running_experiment"
  
  post "experiments/download_results"
  get "experiments/update_state"
  get "experiments/update_list_of_running_experiments"
  
  get "experiments/get_experiment_id"
  get "experiments/get_repository"
  match "experiments/instance_description/:instance_id" => "experiments#instance_description"
  
  match "experiments/next_configuration/:experiment_id" => "experiments#next_configuration"
  match "experiments/file_with_configurations/:experiment_id" => "experiments#file_with_configurations"
  match "experiments/configuration/:experiment_id/:instance_id" => "experiments#configuration"
  match "experiments/set_configuration_done/:experiment_id/:instance_id" => "experiments#set_configuration_done"
  post "experiments/add_chart"
  post "experiments/add_regression_tree_chart"
  post "experiments/add_basic_statistics_chart"
  get "experiments/update_chart_data"
  get "experiments/update_regression_tree"
  get "experiments/update_basic_statistics_chart"
  get "experiments/get_parameter_values"
  post "experiments/extend_input_values"
  post "experiments/check_experiment_size"
  post "experiments/change_scheduling_policy"
  post "experiments/add_bivariate_analysis_chart"
  get "experiments/refresh_bivariate_analysis_chart"

  match "experiments/:id/completed_simulations_count/:secs" => "experiments#completed_simulations_count"
  match "experiments/:id/experiment_stats" => "experiments#experiment_stats"
  match "experiments/:id/experiment_moes" => "experiments#experiment_moes"

  # user controller
  post "user_controller/account"
  get "user_controller/account"
  post "user_controller/change_password"

  resources :experiments

  # infrastructure routes
  match 'infrastructure' => 'infrastructure#index'
  get "infrastructure/index"
  post "infrastructure/index"
  post "infrastructure/register_physical_machine"

  get 'infrastructure/manage_vm'
  match 'infrastructure/update_vm' => 'infrastructure#update_vm'

  get 'infrastructure/manage_pm'
  delete 'infrastructure/manage_pm'
  post 'infrastructure/create_several_vms'
  post 'infrastructure/add_hosts_to_exp'
  post 'infrastructure/add_jobs_to_exp'
  post 'infrastructure/add_vms_to_exp'
  match 'infrastructure/create_vm' => 'infrastructure#create_vm'
  match 'infrastructure/destroy_vm' => 'infrastructure#destroy_vm'

  post "infrastructure/submit_job_to_plgrid"
  post "infrastructure/run_amazon_instances"
  post "infrastructure/manage_ec2_vm"
  get "infrastructure/manage_ec2_vm"

  post "infrastructure/configure_amazon"
  post "infrastructure/configure_plgrid"
  post "infrastructure/configure_plgrid_grouping_factor"

  post "infrastructure/register_simulation_manager_host"
  post "infrastructure/manage_simulation_manager_host"
  
  get 'infrastructure/infrastructure_info'

  resource :socky do
    member do
      post :subscribe
      post :unsubscribe
      post :message
    end
  end

  # The priority is based upon order of creation:
  # first created -> highest priority.

  # Sample of regular route:
  #   match 'products/:id' => 'catalog#view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   match 'products/:id/purchase' => 'catalog#purchase', :as => :purchase
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Sample resource route with options:
  #   resources :products do
  #     member do
  #       get 'short'
  #       post 'toggle'
  #     end
  #
  #     collection do
  #       get 'sold'
  #     end
  #   end

  # Sample resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Sample resource route with more complex sub-resources
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', :on => :collection
  #     end
  #   end

  # Sample resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => "welcome#index"

  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  # match ':controller(/:action(/:id(.:format)))'
end
