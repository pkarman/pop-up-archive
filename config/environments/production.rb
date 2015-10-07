PopUpArchive::Application.configure do
  # Settings specified here will take precedence over those in config/application.rb

  # Code is not reloaded between requests
  config.cache_classes = true

  config.eager_load = true

  # Full error reports are disabled and caching is turned on
  config.consider_all_requests_local       = false
  config.action_controller.perform_caching = true

  # heroku rails 4 requires this
  config.serve_static_files = true

  # Compress JavaScripts and CSS
  config.assets.compress = true

  # Don't fallback to assets pipeline if a precompiled asset is missed
  config.assets.compile = true

  # Generate digests for assets URLs
  config.assets.digest = true

  # Defaults to nil and saved in location specified by config.assets.prefix
  # config.assets.manifest = YOUR_PATH

  # Specifies the header that your server uses for sending files
  # config.action_dispatch.x_sendfile_header = "X-Sendfile" # for apache
  # config.action_dispatch.x_sendfile_header = 'X-Accel-Redirect' # for nginx

  # Force all access to the app over SSL, use Strict-Transport-Security, and use secure cookies.
  # config.force_ssl = true

  # See everything in the log (default is :info)
  config.log_level = :info

  # Prepend all log lines with the following tags
  # config.log_tags = [ :subdomain, :uuid ]

  # Use a different logger for distributed setups
  # config.logger = ActiveSupport::TaggedLogging.new(SyslogLogger.new)
  config.logger = Logger.new(STDOUT)

  # Use a different cache store in production
  config.cache_store = :redis_store, ENV["REDISTOGO_URL"] || "redis://127.0.0.1:6379/0/popuparchive"

  # Enable serving of images, stylesheets, and JavaScripts from an asset server
  # config.action_controller.asset_host = "http://assets.example.com"

  # Precompile additional assets (application.js, application.css, and all non-JS/CSS are already added)
  # config.assets.precompile += %w( search.js )
  config.assets.precompile += %w(*.png *.jpg *.jpeg *.gif *.woff *.ttf *.eot)
  config.assets.precompile += ['directory/base.css', 'directory/application.js', 'login/base.css', 'login.js', 'jplayer.popup.css', 'jquery.js', 'jquery.jplayer.js', 'tplayer.js', 'tplayer-embed.js', 'require.js', 'pua_aa_stylesheet.css', 'jPlayer.css', 'tplayer.css', 'Jplayer.swf', 'bootstrap.min.css', 'bootstrap-theme.min.css']

  # Enable threaded mode
  # config.threadsafe!

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation can not be found)
  config.i18n.fallbacks = true

  # Send deprecation notices to registered listeners
  config.active_support.deprecation = :notify

  # Log the query plan for queries taking more than this (works
  # with SQLite, MySQL, and PostgreSQL)
  # config.active_record.auto_explain_threshold_in_seconds = 0.5

  config.action_mailer.default_url_options = { host: 'www.popuparchive.com', protocol: 'https' }
  Rails.application.routes.default_url_options = { host: 'www.popuparchive.com', protocol: 'https'  }

  #
  #require 'autoscaler/sidekiq'
  #require 'autoscaler/heroku_scaler'
  #Sidekiq.configure_client do |config|
  #  config.client_middleware do |chain|
  #    chain.add Autoscaler::Sidekiq::Client, 'default' => Autoscaler::HerokuScaler.new
  #  end
  #end

  Sidekiq.configure_server do |config|

    database_url = ENV['DATABASE_URL']
    if(database_url)
      ENV['DATABASE_URL'] = "#{database_url}?pool=50"
      ActiveRecord::Base.establish_connection
    end

    #config.server_middleware do |chain|
    #  chain.add(Autoscaler::Sidekiq::Server, Autoscaler::HerokuScaler.new, 300)
    #end
  end
  
  #Prerender.io
  # config.middleware.use Rack::Prerender, prerender_token: ENV['PRERENDER_TOKEN']

  #Obscenity- for filtering terms
  Obscenity.configure do |config|
    config.blacklist   = "config/blacklist.yml"
  end

end
