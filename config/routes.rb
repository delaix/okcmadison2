Rails.application.routes.draw do
  get "pages/home"
  get "pages/about"
  get "pages/classes"
  get "pages/practical"
  get "pages/social"
  
  root :to => 'pages#home'
end
