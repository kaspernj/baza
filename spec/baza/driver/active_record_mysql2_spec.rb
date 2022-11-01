unless RUBY_PLATFORM == "java"
  require "spec_helper"
  Baza.load_driver("active_record")

  describe Baza::Driver::ActiveRecord do
    let(:constant) do
      const_name = "InfoActiveRecordMysql2"
      require "#{__dir__}/../../#{StringCases.camel_to_snake(const_name)}"
      raise "Constant was not defined: '#{const_name}'." unless Baza.const_defined?(const_name)
      Baza.const_get(const_name)
    end

    it_behaves_like "a baza driver"
    it_behaves_like "a baza tables driver"
    it_behaves_like "a baza columns driver"
    it_behaves_like "a baza foreign keys driver"
    it_behaves_like "a baza indexes driver"
    it_behaves_like "a baza users driver"
    it_behaves_like "an active record driver"
    it_behaves_like "a baza importer driver"
  end
end
