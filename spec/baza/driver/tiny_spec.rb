require "spec_helper"

describe Baza::Driver::Tiny do
  describe "#quote_database" do
    it "quotes the given database name" do
      expect(Baza::Driver::Tiny.quote_database("test_database")).to eq "[test_database]"
    end
  end

  describe "#quote_column" do
    it "quotes the given column name" do
      expect(Baza::Driver::Tiny.quote_column("test_column")).to eq "[test_column]"
    end
  end

  describe "#quote_index" do
    it "quotes the given index name" do
      expect(Baza::Driver::Tiny.quote_index("test_index")).to eq "[test_index]"
    end
  end

  describe "#quote_table" do
    it "quotes the given table name" do
      expect(Baza::Driver::Tiny.quote_table("test_table")).to eq "[test_table]"
    end
  end
end
