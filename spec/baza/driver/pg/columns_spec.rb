require "spec_helper"

describe Baza::Driver::Pg::Columns do
  let(:constant) do
    const_name = "InfoPg"
    require StringCases.camel_to_snake(const_name)
    raise "Constant was not defined: '#{const_name}'." unless Baza.const_defined?(const_name)
    Baza.const_get(const_name)
  end
  let(:db) { constant.new.db }

  describe "#data_sql" do
    it "convert int(11) to integer" do
      result = db.columns.data_sql(
        name: "test",
        type: :int,
        maxlength: 11
      )

      expect(result).to eq '"test" integer'
    end

    it "converts int with auto increment to serial" do
      result = db.columns.data_sql(
        name: "test",
        type: :int,
        maxlength: 11,
        autoincr: true
      )

      expect(result).to eq '"test" serial'
    end

    it "converts tinyint to smallint" do
      result = db.columns.data_sql(
        name: "test",
        type: :tinyint,
        maxlength: 11,
        autoincr: true
      )

      expect(result).to eq '"test" smallint'
    end
  end
end
