source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.1.2'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails', branch: 'main'
gem 'rails', '~> 7.0.4'

# Use postgresql as the database for Active Record
gem 'pg', '~> 1.1'

# Use Redis for jobs and caching
gem 'redis', '< 5.0'

# Use the Puma web server [https://github.com/puma/puma]
gem 'puma', '~> 5.0'

# Build JSON APIs with ease [https://github.com/rails/jbuilder]
# gem 'jbuilder'

# Use Kredis to get higher-level data types in Redis [https://github.com/rails/kredis]
# gem 'kredis'

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
# gem 'bcrypt', '~> 3.1.7'

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', require: false

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin AJAX possible
# gem 'rack-cors'

# Settings store
gem 'config'

gem 'travis-lock', github: 'travis-ci/travis-lock'
# Redlock is needed for travis-lock to work
gem 'redlock'

# Background jobs
gem 'sidekiq'
gem 'sidekiq-scheduler'

# Logging
gem 'lograge'

# Sentry error reporting
gem 'sentry-ruby'
gem 'sentry-rails'
gem 'sentry-sidekiq'

# Typed struct classes
gem 'dry-types'
gem 'dry-struct'

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem 'debug'

  gem 'bullet'
  gem 'rspec-rails'
  gem 'factory_bot_rails'
  gem 'faker'
  gem 'rubocop', require: false
  gem 'rubocop-rails', require: false
  gem 'rubocop-performance', require: false
  gem 'rubocop-rspec', require: false
end

group :development do
  # Speed up commands on slow machines / big apps [https://github.com/rails/spring]
  # gem 'spring'

  gem 'annotate'
  gem 'brakeman', require: false
end

group :test do
  gem 'database_cleaner-active_record'
  gem 'timecop'
  gem 'rspec-its'
  gem 'shoulda-matchers'
  gem 'rspec-json_expectations'
  gem 'simplecov', require: false
  gem 'simplecov-console', require: false
end
