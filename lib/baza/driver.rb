#Subclass that contains all the drivers as further subclasses.
class Baza::Driver
  #Autoloader for drivers.
  def self.const_missing(name)
    require_relative "drivers/#{StringCases.camel_to_snake(name)}.rb"
    raise LoadError, "Still not loaded: '#{name}'." unless Baza::Driver.const_defined?(name)
    return Baza::Driver.const_get(name)
  end
end
