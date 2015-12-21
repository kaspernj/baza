require "wref"
require "datet"
require "string-cases"

class Baza
  # Autoloader for subclasses.
  def self.const_missing(name)
    file_name = name.to_s.gsub(/(.)([A-Z])/, '\1_\2').downcase
    require "#{File.dirname(__FILE__)}/baza/#{file_name}.rb"
    raise "Still not defined: '#{name}'." unless Baza.const_defined?(name)
    Baza.const_get(name)
  end

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
end
