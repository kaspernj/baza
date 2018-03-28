require "baza"

if RUBY_PLATFORM == "java"
  require "jdbc/mysql"
  ::Jdbc::MySQL.load_driver

  require "jdbc/sqlite3"
  ::Jdbc::SQLite3.load_driver
end

Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each { |f| require f }

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = [:expect]
  end
end
