Rails.application.routes.draw do
  get "login", to: "sessions#new"
  post "login", to: "sessions#create"
  delete "logout", to: "sessions#destroy"

  root "documents#index"

  resources :documents do
    member do
      get :download_original
      get :download_excel
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
