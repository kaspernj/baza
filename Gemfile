source "http://rubygems.org"
# Add dependencies required to use your gem here.
# Example:
#   gem "activesupport", ">= 2.3.5"

gem "datet", "~> 0.0.25"
gem "wref", "~> 0.0.8"
gem "array_enumerator", "~> 0.0.10"
gem "string-cases", "~> 0.0.1"
gem 'event_handler', '~> 0.0.0'

# Add dependencies to develop your gem here.
# Include everything needed to run rake, tests, features, etc.
group :development, :test do
  gem "rspec"
  gem "rdoc"
  gem "bundler"
  gem "jeweler"
  gem 'pry'

  gem "jdbc-sqlite3", platforms: :jruby
  gem "activerecord-jdbc-adapter", platforms: :jruby

  gem "sqlite3", platforms: :ruby
  gem 'mysql', platforms: :ruby
  gem "mysql2", platforms: :ruby

  gem "activerecord"
end

gem "codeclimate-test-reporter", group: :test, require: nil
