Rails.application.routes.draw do
  root "documents#index"

  resources :documents do
    member do
      get :download_original
      get :download_excel
    end
  end
end
