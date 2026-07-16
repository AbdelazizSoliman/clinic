Rails.application.routes.draw do
  devise_for :users, controllers: { sessions: "users/sessions", registrations: "users/registrations" }
  root "home#index"
  resources :products, only: %i[index show]
  resources :categories, only: :show
  resource :cart, only: :show do
    post :clear
    post :import_browser
  end
  resources :cart_items, only: %i[create update destroy]
  get "wishlist", to: "wishlists#show", as: :wishlist
  resource :wishlist, only: [] do
    delete :clear
    post :import_browser
  end
  resources :wishlist_items, only: %i[create destroy]
  get "checkout", to: "shopping#checkout", as: :checkout
  resources :orders, only: %i[index show create], param: :number do
    get "prescription_files/:attachment_id", to: "prescription_files#show", as: :prescription_file
  end
  resource :account, only: %i[show edit update], controller: "account"
  namespace :account do
    resources :addresses, except: :show do
      member do
        patch :set_default
        patch :deactivate
      end
    end
  end
  namespace :staff do
    root "dashboard#index"
    resources :orders, only: %i[index show], param: :number do
      member { patch :transition }
    end
    resources :prescriptions, only: %i[index show] do
      member { patch :review }
      get "files/:attachment_id", to: "prescription_files#show", as: :file
    end
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
end
