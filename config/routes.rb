Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker

  # Admin area — all controllers inherit Admin::BaseController, which requires login.
  namespace :admin do
    root "dashboard#index"
    resources :shows, except: :show do
      member { patch :toggle_featured }
      collection { post :sync }
    end
    resources :subscribers, only: %i[index new create destroy] do
      member { post :resend_confirmation }
    end
    resources :newsletters do
      member do
        get  :preview
        post :send_now
        post :schedule
        post :cancel
        post :regenerate
      end
      collection do
        post :generate
      end
    end
    resources :products do
      resources :variants, except: %i[show index]
    end
    resources :orders, only: %i[index show] do
      member { patch :fulfill }
    end
    resources :photos, except: :show do
      collection { patch :bulk_update }
    end
    resources :videos, only: %i[index update] do
      collection { post :sync }
    end
  end

  # Public, fan-facing pages
  get "about" => "pages#about", as: :about
  get "shows/past" => "shows#past", as: :past_shows
  resources :shows, only: :index
  resources :products, only: %i[index show]
  resource :cart, only: %i[show] do
    resources :cart_items, only: %i[create update destroy]
  end
  post "checkout" => "checkout#create", as: :checkout
  get  "orders/:id/success" => "orders#success", as: :order_success
  get  "orders/:id/cancel"  => "orders#cancel",  as: :order_cancel
  post "webhooks/stripe" => "stripe_webhooks#create", as: :stripe_webhook
  resources :push_subscriptions, only: :create

  # Newsletter (account-free, double opt-in)
  post "newsletter/subscribe"          => "newsletter/subscriptions#create",  as: :newsletter_subscribe
  get  "newsletter/confirm/:token"     => "newsletter/subscriptions#confirm", as: :newsletter_confirm
  get  "newsletter/unsubscribe/:token" => "newsletter/unsubscribes#show",     as: :newsletter_unsubscribe
  post "newsletter/unsubscribe/:token" => "newsletter/unsubscribes#create"

  get "sitemap.xml"  => "sitemaps#show",  as: :sitemap
  get "robots.txt"   => "robots#show",    as: :robots

  # Defines the root path route ("/")
  root "pages#home"
end
