require "spec_helper"

describe Baza::Driver::Pg::Table do
  let(:constant) do
    const_name = "InfoPg"
    require StringCases.camel_to_snake(const_name)
    raise "Constant was not defined: '#{const_name}'." unless Baza.const_defined?(const_name)
    Baza.const_get(const_name)
  end
  let(:driver) { constant.new }
  let(:db) { driver.db }

  describe "#native?" do
    it "returns true if the table is 'pg_stat_statements'-table" do
      test_table = Baza::Driver::Pg::Table.new(driver: driver, data: {table_name: "pg_stat_statements"})

      expect(test_table.native?).to be true
    end
  end
end
