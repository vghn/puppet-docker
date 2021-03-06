source 'https://rubygems.org'

gem 'docker-api', require: false
gem 'faraday', require: false
gem 'json', require: false
gem 'puma', require: false
gem 'rack', require: false
gem 'rake', require: false
gem 'sinatra', require: false
gem 'slack-notifier', require: false

group :development do
  gem 'rack-test', require: false
  gem 'reek', require: false
  gem 'rspec', require: false
  gem 'rubocop', require: false
  gem 'rubycritic', require: false
  gem 'travis', require: false
end
