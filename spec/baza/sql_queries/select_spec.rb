require "spec_helper"

describe Baza::SqlQueries::Select do
  let(:constant) do
    const_name = "InfoPg"
    require StringCases.camel_to_snake(const_name)
    raise "Constant was not defined: '#{const_name}'." unless Baza.const_defined?(const_name)
    Baza.const_get(const_name)
  end
  let(:db) { constant.new.db }

  before do
    db.tables[:test].drop

    db.tables.create(
      "test",
      columns: [
        {name: "id", type: :int, autoincr: true, primarykey: true},
        {name: "text", type: :varchar},
        {name: "number", type: :int, default: 0},
        {name: "float", type: :float, default: 0.0},
        {name: "created_at", type: :datetime}
      ]
    )

    1000.times do |count|
      db.insert("test", text: "Test #{count}", number: count, float: count)
    end
  end

  describe "#total_pages" do
    it "returns the correct amount of pages" do
      query = db.new_query.from("test").per_page(30)

      expect(query.total_pages).to eq 34
    end
  end
end
