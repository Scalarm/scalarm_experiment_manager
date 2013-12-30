ScalarmExperimentManager::Application.routes.draw do
  # The priority is based upon order of creation: first created -> highest priority.
  # See how all your routes lay out with "rake routes".

  # You can have the root of your site routed with "root"
  root 'experiments#index'

  get 'login' => 'user_controller#login'
  post 'login' => 'user_controller#login'
  post 'logout' => 'user_controller#logout'
  get 'user_controller/account'
  post 'user_controller/change_password'

  # OpenID
  get 'login/login_openid_google' => 'user_controller#login_openid_google'
  get 'login/openid_callback_google' => 'user_controller#openid_callback_google'

  get 'simulations' => 'simulations#index'
  get 'simulations/index'
  get 'simulations/registration'
  post 'simulations/upload_component'
  post 'simulations/destroy_component'
  post 'simulations/upload_simulation'
  post 'simulations/destroy_simulation'
  post 'simulations/conduct_experiment'

  resources :experiments do
    collection do
      post :start_experiment
      post :calculate_experiment_size
      get :running_experiments
      get :historical_experiments
    end

    member do
      get   :code_base
      get   :next_simulation
      get   :parameter_values
      get   :file_with_configurations

      post  :stop
      post  :destroy
      post  :extend_input_values
      get   :intermediate_results
      get   :get_booster_dialog
      get   :extension_dialog
      post  :change_scheduling_policy

      # experiment charts
      post :histogram
      post :scatter_plot
      post :regression_tree

      get :running_simulations_table
      get :completed_simulations_table
      #get :experiment_results_table

      # Progress monitoring API
      get :completed_simulations_count
      get :experiment_stats
      get :experiment_moes
    end

    resources :simulations do
      member do
        post :mark_as_complete
        post :progress_info
        get  :get_simulation_data
      end
    end
  end

  get 'simulations/simulation_scenarios' => 'simulations#simulation_scenarios'

  resource :infrastructure do
    member do
      post :schedule_simulation_managers
      get :infrastructure_info
      post :add_infrastructure_credentials
    end
  end

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
