require "sidekiq/web"

Rails.application.routes.draw do
  mount Sidekiq::Web => "/sidekiq"

  root "documents#index"

  resources :documents do
    member do
      get :download_original
      get :download_excel
    end
  end
end
