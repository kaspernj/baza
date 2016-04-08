require "spec_helper"

unless RUBY_PLATFORM == "java"
  describe Baza.const_get(:Driver).const_get(:Pg) do
    let(:constant) do
      const_name = "InfoPg"
      require "#{File.dirname(__FILE__)}/../#{StringCases.camel_to_snake(const_name)}"
      raise "Constant was not defined: '#{const_name}'." unless Baza.const_defined?(const_name)
      Baza.const_get(const_name)
    end

    it_should_behave_like "a baza driver"
    it_should_behave_like "a baza databases driver"
    it_should_behave_like "a baza tables driver"
    it_should_behave_like "a baza columns driver"
    it_should_behave_like "a baza indexes driver"
  end
end
