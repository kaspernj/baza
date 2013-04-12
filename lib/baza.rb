class Baza
  #Autoloader for subclasses.
  def self.const_missing(name)
    require "#{File.dirname(__FILE__)}/../include/#{name.to_s.downcase}.rb"
    raise "Still not defined: '#{name}'." if !Baza.const_defined?(name)
    return Baza.const_get(name)
  end
end