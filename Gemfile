source 'https://rubygems.org'
git_source(:github) { |repo| "https://github.com/#{repo}.git" }

ruby '3.1.2'

gem 'config'
gem 'pg'
gem 'puma', '~> 5.0'
gem 'rails', '~> 7.0.3', '>= 7.0.3.1'
gem 'redis'
gem 'sidekiq'
gem 'sentry-rails'
gem 'sentry-ruby'
gem 'sentry-sidekiq'
gem 'travis-lock', github: 'travis-ci/travis-lock'

gem 'bootsnap', require: false

group :development, :test do
  gem 'brakeman'
  gem 'byebug', platforms: [:mri, :mingw, :x64_mingw]
  gem 'factory_bot'
  gem 'rspec-rails'
  gem 'listen'
end

group :test do
  gem 'rspec'
  gem 'database_cleaner'
end

group :development do
  gem 'rubocop'
  gem 'rubocop-rspec'
end
