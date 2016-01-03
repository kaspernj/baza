require "auto_autoloader"
require "array_enumerator"
require "wref"
require "datet"
require "string-cases"

class Baza
  AutoAutoloader.autoload_sub_classes(self, __FILE__)

  class << self
    attr_writer :default_db
  end

  def self.default_db
    unless @default_db
      config_file = "#{Dir.pwd}/config/baza_database.rb"
      init_file = "#{Dir.pwd}/config/initializers/baza_database.rb"

      begin
        load(config_file)
      rescue LoadError
        load(init_file)
      end

      unless @default_db.is_a?(Baza::Db)
        raise "Config file didn't return a Baza::Db: #{@default_db.class.name}"
      end
    end

    @default_db
  end

  def self.drivers
    Enumerator.new do |yielder|
      Dir.foreach("#{File.dirname(__FILE__)}/baza/driver") do |file|
        if (match = file.match(/\A(.+?)\.rb\Z/))
          load_driver(match[1])

          driver_name = StringCases.snake_to_camel(match[1])
          yielder << {
            class: Baza::Driver.const_get(driver_name),
            snake_name: match[1],
            camel_name: driver_name
          }
        end
      end
    end
  end

  def self.load_driver(name)
    require_relative "baza/driver/#{name}"

    loads = %w(databases database tables table columns column indexes index result)
    loads.each do |load|
      file_path = "#{File.dirname(__FILE__)}/baza/driver/#{name}/#{load}"
      require_relative file_path if File.exist?(file_path)
    end
  end
end
