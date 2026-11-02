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
      member { patch :toggle_featured; patch :stats }
      collection { post :sync }
    end
    resources :subscribers, only: %i[index new create destroy] do
      member { post :resend_confirmation }
      collection { get :import; post :import }
    end
    resources :newsletters do
      member do
        get  :preview
        post :send_now
        post :schedule
        post :cancel
        post :regenerate
        post :resend
      end
      collection do
        post :generate
      end
    end
    resources :products do
      resources :variants, except: %i[show index] do
        collection { post :add_sizes }
      end
    end
    resources :orders, only: %i[index show] do
      member { patch :fulfill }
    end
    resources :photos, except: :show do
      collection do
        patch :bulk_update
        get   :visible
        patch :reorder
      end
    end
    resources :videos, only: %i[index update] do
      collection { post :sync }
    end
    resource :push_notification, only: %i[new create]
  end

  # Public, fan-facing pages
  get "about" => "pages#about", as: :about
  get "epk" => "pages#epk", as: :epk # unlisted booker press kit (noindex, not in nav/sitemap)
  get "privacy" => "pages#privacy", as: :privacy
  get "tos" => "pages#tos", as: :tos
  get "shows/past" => "shows#past", as: :past_shows
  resources :shows, only: %i[index show]
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
