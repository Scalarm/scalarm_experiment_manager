require File.join(Rails.root, 'app/models/openid_providers/google_openid')
require File.join(Rails.root, 'app/models/openid_providers/github_oauth')

ScalarmExperimentManager::Application.routes.draw do

  resources :simulation_managers do
    member do
      get :code
    end
  end

  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'user_controller#index'

  get 'login' => 'user_controller#login'
  post 'login' => 'user_controller#login'
  post 'logout' => 'user_controller#logout'
  get 'user_controller/account'
  post 'user_controller/change_password'
  get 'status' => 'user_controller#status'

  # OAuth

  if GoogleOpenID.google_configured?
    get 'login/login_oauth_google' => 'user_controller#login_oauth_google'
    get 'login/oauth2_google_callback' => 'user_controller#oauth2_google_callback'
  end

  if GithubOauth.github_configured?
    get 'login/login_oauth_github' => 'user_controller#login_oauth_github'
    get 'login/oauth2_github_callback' => 'user_controller#oauth2_github_callback'
  end


  # OpenID

  ## Google OpenID - deprecated
  # get 'login/login_openid_google' => 'user_controller#login_openid_google'
  # get 'login/openid_callback_google' => 'user_controller#openid_callback_google'

  get 'login/login_openid_plgrid' => 'user_controller#login_openid_plgrid'
  post 'login/openid_callback_plgrid' => 'user_controller#openid_callback_plgrid'

  get 'simulation_scenarios' => 'simulations#index'
  get 'simulations' => 'simulations#index'
  get 'simulations/index'
  get 'simulations/registration'
  post 'simulations/upload_component'
  post 'simulations/destroy_component'
  post 'simulations' => 'simulations#create'

  get 'infrastructures' => 'infrastructures#index'

  get 'simulation_scenarios/:id/experiments' => 'simulation_scenarios#get_simulation_scenario_experiment_ids'
  resources :experiments do
    collection do
      post :start_import_based_experiment, to: 'experiments#create'
      post :calculate_experiment_size
      post :calculate_imported_experiment_size
      get :running_experiments
      get :completed_experiments
      get :historical_experiments
      get :random_experiment
    end

    member do
      get   :code_base
      get   :next_simulation
      get   :parameter_values
      get   :file_with_configurations
      get   :configurations
      get   :results_binaries

      post  :stop
      post  :extend_input_values
      get   :intermediate_results
      get   :extension_dialog
      post  :change_scheduling_policy
      post  :schedule_point
      post  :schedule_multiple_points
      get   :get_result

      # experiment charts
      post :histogram
      post :scatter_plot
      post :regression_tree
      get :scatter_plot_series

      get :running_simulations_table
      get :completed_simulations_table
      #get :experiment_results_table

      # Progress monitoring API
      get :completed_simulations_count
      get :experiment_stats, to: 'experiments#stats'
      get :stats
      get :experiment_moes, to: 'experiments#moes'
      get :moes
      get :moes_json
      get :results_info

      get :simulation_manager

      post :share

      # Optimization experiment
      post :mark_as_complete
    end

    resources :simulations do
      member do
        post :mark_as_complete
        post :progress_info
        get  :progress_info_history
        get  :get_simulation_data
        get  :results_binaries
        get  :results_stdout
      end
    end
  end

  get 'simulations/simulation_scenarios' => 'simulations#simulation_scenarios'
  post 'simulations/upload_parameter_space'

  resource :infrastructure do
    member do
      post :schedule_simulation_managers
      get :infrastructure_info
      post :add_infrastructure_credentials
      get :get_infrastructure_credentials
      post :remove_credentials
    end

    collection do
      get :list
      get :simulation_managers_info
      get :simulation_managers_summary
      get :get_sm_dialog
      get :get_booster_dialog
      get :get_booster_partial
      get :get_credentials_partial
      get :get_credentials_table_partial
      get :get_resource_status
      get :simulation_manager_records
      post :simulation_manager_command
    end
  end

  resources 'simulation_scenarios' do
    member do
      get :code_base
      post :share
    end
  end

  resources :clusters do
    collection do
      get :credentials
    end
  end

  require 'sidekiq/web'
  Sidekiq::Web.set :session_secret, Rails.application.secrets[:secret_token]
  Sidekiq::Web.set :sessions, Rails.application.config.session_options

  Sidekiq::Web.use Rack::Auth::Basic do |username, password|
    username == Rails.application.secrets.sidekiq_username && password == Rails.application.secrets.sidekiq_password
  end

  mount Sidekiq::Web => '/sidekiq'

  # Example of regular route:
  #   get 'products/:id' => 'catalog#view'

  # Example of named route that can be invoked with purchase_url(id: product.id)
  #   get 'products/:id/purchase' => 'catalog#purchase', as: :purchase

  # Example resource route (maps HTTP verbs to controller actions automatically):
  #   resources :products

  # Example resource route with options:
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

  # Example resource route with sub-resources:
  #   resources :products do
  #     resources :comments, :sales
  #     resource :seller
  #   end

  # Example resource route with more complex sub-resources:
  #   resources :products do
  #     resources :comments
  #     resources :sales do
  #       get 'recent', on: :collection
  #     end
  #   end

  # Example resource route with concerns:
  #   concern :toggleable do
  #     post 'toggle'
  #   end
  #   resources :posts, concerns: :toggleable
  #   resources :photos, concerns: :toggleable

  # Example resource route within a namespace:
  #   namespace :admin do
  #     # Directs /admin/products/* to Admin::ProductsController
  #     # (app/controllers/admin/products_controller.rb)
  #     resources :products
  #   end
end
