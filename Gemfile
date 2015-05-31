source "http://rubygems.org"
# Add dependencies required to use your gem here.
# Example:
#   gem "activesupport", ">= 2.3.5"

gem "datet", "~> 0.0.25"
gem "wref", "~> 0.0.8"
gem "array_enumerator", "~> 0.0.7"
gem "string-cases", "~> 0.0.1"
gem 'event_handler', '~> 0.0.0'

# Add dependencies to develop your gem here.
# Include everything needed to run rake, tests, features, etc.
group :development do
  gem "rspec"
  gem "rdoc"
  gem "bundler"
  gem "jeweler"

  if RUBY_ENGINE == "jruby"
    gem "jdbc-sqlite3"
    gem "activerecord-jdbc-adapter"
  else
    gem "sqlite3"
    gem "mysql2"
  end

  gem "activerecord"
end

gem "codeclimate-test-reporter", group: :test, require: nil
