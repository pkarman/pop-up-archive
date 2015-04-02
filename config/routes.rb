PopUpArchive::Application.routes.draw do

  use_doorkeeper do
    controllers :applications => 'oauth/applications'
  end

  # get '/*path' => redirect {|params, request| "https://www.popuparchive.com/#{params[:path]}" }, constraints: { host: 'pop-up-archive.herokuapp.com' }
  get '/*path' => redirect {|params, request| "https://www.popuparchive.com/#{params[:path]}" }, constraints: { host: 'beta.popuparchive.org' }
  get '/*path' => redirect {|params, request| "https://www.popuparchive.com/#{params[:path]}" }, constraints: { host: 'www.popuparchive.org', protocol: "http://" }
  get '/*path' => redirect {|params, request| "https://www.popuparchive.com/#{params[:path]}" }, constraints: { host: 'www.popuparchive.org', protocol: "https://" }
  get '/*path' => redirect {|params, request| "https://www.popuparchive.com/#{params[:path]}" }, constraints: { host: 'www.popuparchive.com', protocol: "http://" }
  get '/*path' => redirect {|params, request| "https://www.popuparchive.com/#{params[:path]}" }, constraints: { host: 'popuparchive.com'}
  get '/*path' => redirect {|params, request| "https://www.popuparchive.com/#{params[:path]}" }, constraints: { host: 'popuparchive.org'}
  root to: redirect('https://www.popuparchive.com/'), constraints: { host: 'www.popuparchive.org', protocol: 'http://' }
  root to: redirect('https://www.popuparchive.com/'), constraints: { host: 'www.popuparchive.org', protocol: 'https://' }
  root to: redirect('https://www.popuparchive.com/'), constraints: { host: 'beta.popuparchive.org' }
  # root to: redirect('https://www.popuparchive.com/'), constraints: { host: 'pop-up-archive.herokuapp.com' }
  root to: redirect('https://www.popuparchive.com/'), constraints: { host: 'www.popuparchive.com', protocol: 'http://' }
  root to: redirect('https://www.popuparchive.com/'), constraints: { host: 'popuparchive.com' }
  root to: redirect('https://www.popuparchive.com/'), constraints: { host: 'popuparchive.org' }

  #devise_for ActiveAdmin::Devise.config
  devise_for :users, controllers: { registrations: 'users/registrations', invitations: 'users/invitations', omniauth_callbacks: 'users/omniauth_callbacks', sessions: 'users/sessions' }
  ActiveAdmin.routes(self)

  namespace :admin do
    resources :task_list
    resources :soundcloud_callback
    get 'total_usage', to: 'accounts#total_usage'
    resources :accounts
  end

  get 'su' => 'switch_user#set_current_user'

  get 'media/:token/:expires/:use/:class/:id/:name.:extension', controller: 'media', action: 'show', constraints: {name: /[^\/]+/}
  get 'media/:class/:idhex/:name.:extension', controller: 'media', action: 'permanent', constraints: {name: /[^\/]+/}
  
  get 'embed_player/:name/:file_id/:item_id/:collection_id', to: 'embed_player', action: 'show'

  get 'tplayer/:file_id',        to: 'embed_player', action: 'tplayer'
  get 'tplayer/:file_id/:title', to: 'embed_player', action: 'tplayer'

  get 'oembed', to: 'oembed', action: 'show'

  post 'fixer_callback/:id', controller: 'callbacks', action: 'fixer', as: 'audio_file_fixer_callback', model_name: 'audio_file'

  post 'fixer_callback/files/:model_name/:id', controller: 'callbacks', action: 'fixer', as: 'fixer_callback'

  post 'amara_callback', controller: 'callbacks', action: 'amara', as: 'amara_callback'

  post 'speechmatics_callback/files/:model_name/:model_id', controller: 'callbacks', action: 'speechmatics', as: 'speechmatics_callback'

  post 'stripe_webhook', controller: 'callbacks', action: 'stripe_webhook', as: 'stripe_webhook'
  
  get 'sitemap.xml', :to => 'sitemap#sitemap', as: 'sitemap', defaults: { format: 'xml' }

  post 'headcheck', :to => 'api/v1/audio_files#head_check'
    

  namespace :api, defaults: { format: 'json' }, path: 'api' do
    scope module: :v1, constraints: ApiVersionConstraint.new(version: 1, default: true) do
      root to: 'status#info'

      get '/stats' => 'status#stats'

      get '/me' => 'users#me'
      put '/me/credit_card' => 'credit_cards#update'
      put '/me/subscription' => 'subscriptions#update'
      get '/users/me' => 'users#me'
      put '/users/me/credit_card' => 'credit_cards#update'
      put '/users/me/subscription' => 'subscriptions#update'

      get '/usage'        => 'users#usage'
      get '/usage/:limit' => 'users#usage'
      get '/users/usage'  => 'users#usage'
      get '/users/usage/:limit' => 'users#usage'

      post '/credit_card' => 'credit_cards#save_token'

      get '/test/croak' => 'test#croak'
      resources :test

      resource :last_items
      resource :search
      resources :items, only: [] do
        resources :audio_files do
          post '',                     action: 'update'
          get  'transcript_text',      action: 'transcript_text'
          get  'upload_to',            action: 'upload_to'
          post 'order_transcript',     action: 'order_transcript'
          post 'add_to_amara',         action: 'add_to_amara'
          post 'listens',              action: 'listens'
          get  'transcript/premium/cost',  action: 'premium_transcript_cost'
          post 'transcript/premium/order', action: 'order_premium_transcript'

          # s3 upload actions
          get  'chunk_loaded',         action: 'chunk_loaded'
          get  'get_init_signature',   action: 'init_signature'
          get  'get_chunk_signature',  action: 'chunk_signature'
          get  'get_end_signature',    action: 'end_signature'
          get  'get_list_signature',   action: 'list_signature'
          get  'get_delete_signature', action: 'delete_signature'
          get  'get_all_signatures',   action: 'all_signatures'
          get  'upload_finished',      action: 'upload_finished'

          resource :transcript
        end
        resources :image_files do 
          get  'upload_to',            action: 'upload_to'
          
          # s3 upload actions
          get  'chunk_loaded',         action: 'chunk_loaded'
          get  'get_init_signature',   action: 'init_signature'
          get  'get_chunk_signature',  action: 'chunk_signature'
          get  'get_end_signature',    action: 'end_signature'
          get  'get_list_signature',   action: 'list_signature'
          get  'get_delete_signature', action: 'delete_signature'
          get  'get_all_signatures',   action: 'all_signatures'
          get  'upload_finished',      action: 'upload_finished'
        end
        resources :entities
        resources :contributions
      end

      resources :transcripts

      resources :timed_texts

      resources :speakers

      resources :organizations

      resources :plans

      resources :collections do
        collection do
          resources :public_collections, path: 'public', only: [:index]
        end
        resources :items
        resources :people
        resources :image_files do 
          get  'upload_to',            action: 'upload_to'
          
          # s3 upload actions
          get  'chunk_loaded',         action: 'chunk_loaded'
          get  'get_init_signature',   action: 'init_signature'
          get  'get_chunk_signature',  action: 'chunk_signature'
          get  'get_end_signature',    action: 'end_signature'
          get  'get_list_signature',   action: 'list_signature'
          get  'get_delete_signature', action: 'delete_signature'
          get  'get_all_signatures',   action: 'all_signatures'
          get  'upload_finished',      action: 'upload_finished'
        end
      end
      resources :csv_imports
    end
  end

  # used only for dev and test
  mount JasmineRails::Engine => "/jasmine" if defined?(JasmineRails)

  authenticate :user, lambda { |u| u.super_admin? } do
    require 'sidekiq/web'
    mount Sidekiq::Web => '/admin/sidekiq'
  end

  match '/api/*path', to: 'api/base#not_found'
  match '*path', to: 'directory/dashboard#user'
  root to: 'directory/dashboard#guest', constraints: GuestConstraint.new(true)
  root to: 'directory/dashboard#user', constraints: GuestConstraint.new(false)
end
