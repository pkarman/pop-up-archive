source 'https://rubygems.org'

ruby '2.0.0'

gem 'rails', '~> 4.2.3' 

# these used to be in the "assets" group under Rails 3
# but that group is removed in Rails 4 so we include here.
# NOTE that sass-rails, uglifier and coffee-rails seem
# to be included by Rails core now so we disabled them here.
#gem 'sass-rails'
gem 'uglifier'
#gem 'coffee-rails'
#gem 'bootstrap-sass'
gem 'bootstrap_form'
gem 'angularjs-rails-resource', '= 0.2.5'
gem 'ng_player_hater-rails'

gem 'etagger', github: 'rails/etagger'
gem 'dalli'

gem 'dotenv'
gem 'fixer_client', :git => 'git://github.com/PRX/fixer_client.git'
gem 'pg'
gem 'postgres_ext'
gem 'acts_as_list', '= 0.6.0'
gem 'multi_json'

gem 'decent_exposure'
# gem 'decent_exposure', github: 'voxdolo/decent_exposure'

# back compat with Rails 3
gem 'protected_attributes'

# login to prx.org using omniauth
gem 'omniauth'
gem 'omniauth-oauth2', '~> 1.1.0'
gem 'omniauth-prx', github: 'PRX/omniauth-prx'
gem 'omniauth-twitter'
gem 'omniauth-facebook'
gem 'devise', '~> 3.4.1'
gem 'devise_invitable', github: 'scambra/devise_invitable'
gem 'switch_user'
gem 'cancancan', '~> 1.10.1'

# require a new enough rest-client on behalf of other gems that use it
# NOTE that v 1.7.2 has a security bug but it is the newest version as of 2015-01-27
gem 'rest-client', '~> 1.7.2'

# search with elasticsearch
gem 'kaminari'
gem 'elasticsearch-model', '~> 0.1.6'
gem 'elasticsearch-rails', '~> 0.1.6'
gem 'elasticsearch-rails-ha', github: '18F/elasticsearch-rails-ha-gem'
gem 'fuzzy_match', '~> 2.1.0'
gem 'stopwords-filter'
gem 'lucene_query_parser', :git => 'git://github.com/pkarman/lucene_query_parser.git', :branch => 'term-regex'

# server-side templates
gem 'slim-rails'
gem 'rabl'

# background processing
gem 'sidekiq'
gem 'sidekiq-unique-jobs'

# misc
gem 'copyrighter'
gem 'geocoder'
gem 'will_paginate'

gem 'carrierwave'
gem 'cloudfront-signer'

gem 'rmagick'
gem 'mini_magick', :git => 'git://github.com/fschwahn/mini_magick.git'
gem 'fog', '~> 1.30.0'

gem 'heroku-api', '~> 0.3.22'
gem 'excon'

gem 'pb_core', '~> 0.1.6'
# gem 'pb_core', path: '~/dev/projects/pb_core'

gem 'chronic'

gem 'state_machine'

gem 'doorkeeper', "~> 1.4.2"

#gem "acts_as_paranoid", github: 'pkarman/acts_as_paranoid', branch: 'rails4.2'
gem "paranoia", :github => "radar/paranoia", :branch => "rails4"

gem 'newrelic_rpm'

gem 'feedjira'

gem 'rolify', "~> 3.4.1"

gem 'sanitize'

gem 'soundcloud'

gem 'amara', github: 'pkarman/amara'

gem 'speechmatics', github: 'popuparchive/speechmatics', :branch => 'rails3'
gem 'voicebase', github: 'popuparchive/voicebase-client-ruby'

gem 'prerender_rails'

gem 'countries'
gem 'language_list'

gem 'stripe', '= 1.20.1'

gem 'redis-namespace', '>= 1.3.1'
gem 'redis-rails'

gem 'jplayer-rails'

gem 'gibbon'

gem 'rack-cors'

gem 'dbpedia'

gem 'obscenity'

gem 'text-table'

gem 'mixpanel-ruby'
gem 'staccato'

gem 'jquery-rails', '>= 4.0.4'
gem 'activeadmin', github: 'activeadmin', branch: 'master'
gem 'active_admin_sidebar'
gem 'coffee-script'
gem 'ansi'

group :development do
  gem 'quiet_assets'
  gem 'better_errors'
  gem 'binding_of_caller'
  gem 'ruby_gntp'
  gem 'guard-rspec'
  gem 'guard-jasmine'
  gem "guard-bundler", ">= 1.0.0"
  gem 'spring'
  gem 'pry-rails'
  gem 'pry-stack_explorer'
  gem 'byebug'
  gem 'pry-remote'
 end

group :development, :test do
  gem 'rspec-rails', '~> 3.1'
  gem 'rspec-mocks'
  gem 'rspec-its'
  gem 'database_cleaner'
  gem 'listen'
  gem 'terminal-notifier-guard'
  gem 'growl', require: false
  gem 'rb-inotify', require: false
  gem 'rb-fsevent', require: false
  gem 'rb-fchange', require: false

  # Test JS using Jasmine
  gem 'jasmine'
  gem 'jasmine-rails'
    
end

group :test do
  gem 'factory_girl_rails'
  gem 'capybara'
  gem 'poltergeist'
  gem 'shoulda-matchers'
  gem 'stripe-ruby-mock', '= 2.0.5', require: 'stripe_mock'
  gem 'simplecov'
  gem 'coveralls'
  gem 'elasticsearch-extensions'
  gem 'test_after_commit'
  gem 'timecop'
end

group :development, :production, :staging do
  gem 'sinatra' # for sidekiq
  gem 'autoscaler', '~> 0.2.0'
  gem 'foreman'
  gem 'unicorn'
end

group :production, :staging do
  gem 'rails_12factor'
end
