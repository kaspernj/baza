require "spec_helper"
require_relative "../../lib/baza/driver/active_record"

describe Baza::Driver::ActiveRecord do
  let(:constant) do
    const_name = "InfoActiveRecordSqlite3"
    require "#{File.dirname(__FILE__)}/../#{StringCases.camel_to_snake(const_name)}"
    raise "Constant was not defined: '#{const_name}'." unless Baza.const_defined?(const_name)
    Baza.const_get(const_name)
  end

  it_behaves_like "a baza driver"
  it_should_behave_like "a baza tables driver"
  it_should_behave_like "a baza columns driver"
  it_should_behave_like "a baza indexes driver"
  it_should_behave_like "an active record driver"
  it_should_behave_like "a baza importer driver"
end
