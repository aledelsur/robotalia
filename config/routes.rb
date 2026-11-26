require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  resource :session, only: %i[new create destroy]
  resources :accounts, only: %i[index show] do
    resources :trades, only: :index
  end
  resources :account_imports, path: "imports", only: %i[new create show]

  # Sidekiq's dashboard is only routable for the signed-in owner; anyone else gets a 404.
  constraints OwnerSessionConstraint.new do
    mount Sidekiq::Web => "/sidekiq"
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/* (remember to link manifest in application.html.erb)
  # get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  # get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  root "accounts#index"
end
