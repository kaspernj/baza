require "spec_helper"

unless RUBY_PLATFORM == "java"
  describe Baza::Driver::ActiveRecord do
    let(:constant) do
      name = described_class.name.split("::").last
      const_name = "InfoActiveRecordPg"
      require "#{File.dirname(__FILE__)}/../#{StringCases.camel_to_snake(const_name)}"
      raise "Constant was not defined: '#{const_name}'." unless Baza.const_defined?(const_name)
      Baza.const_get(const_name)
    end

    it_behaves_like "a baza driver"
    it_should_behave_like "a baza tables driver"
    it_should_behave_like "a baza columns driver"
    it_should_behave_like "a baza indexes driver"
  end
end
