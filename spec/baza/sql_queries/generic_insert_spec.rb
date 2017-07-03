require "spec_helper"

describe Baza::SqlQueries::GenericInsert do
  let(:constant) do
    const_name = "InfoPg"
    require StringCases.camel_to_snake(const_name)
    raise "Constant was not defined: '#{const_name}'." unless Baza.const_defined?(const_name)
    Baza.const_get(const_name)
  end
  let(:db) { constant.new.db }

  describe "#convert_line_breaks" do
    it "converts line breaks to valid postgres sql" do
      generic_insert = Baza::SqlQueries::GenericInsert.new(
        db: db,
        table_name: "test_table",
        data: {
          "test_column" => "data\nwith\nline\nbreaks"
        },
        replace_line_breaks: true
      )

      expect(generic_insert.to_sql).to eq "INSERT INTO \"test_table\" (\"test_column\") VALUES ('data' || CHR(10) || 'with' || CHR(10) || 'line' || CHR(10) || 'breaks')"
    end
  end
end
