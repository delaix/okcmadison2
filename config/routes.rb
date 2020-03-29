Rails.application.routes.draw do
  get "pages/home"
  get "pages/about"
  get "pages/classes"
  get "pages/blog"
  get "pages/practical"
  
  root :to => 'pages#home'
end
