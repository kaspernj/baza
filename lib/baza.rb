require "string-cases"

class Baza
  #Autoloader for subclasses.
  def self.const_missing(name)
    file_name = name.to_s.gsub(/(.)([A-Z])/,'\1_\2').downcase
    require "#{File.dirname(__FILE__)}/../include/#{file_name}.rb"
    raise "Still not defined: '#{name}'." if !Baza.const_defined?(name)
    return Baza.const_get(name)
  end
end
