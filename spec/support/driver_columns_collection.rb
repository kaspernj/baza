shared_examples_for "a baza columns driver" do
  let(:constant){
    name = described_class.name.split("::").last
    const_name = "Info#{name.slice(0, 1).upcase}#{name.slice(1, name.length)}"
    require "#{File.dirname(__FILE__)}/../info_#{StringCases.camel_to_snake(name)}"
    raise "Constant was not defined: '#{const_name}'." unless Baza.const_defined?(const_name)
    Baza.const_get(const_name)
  }
  let(:driver){ constant.new }
  let(:db){ driver.db }
  let(:test_table){
    db.tables.create("test", {
      columns: [
        {name: "id", type: :int, autoincr: true, primarykey: true},
        {name: "text", type: :varchar}
      ]
    })
    db.tables[:test]
  }

  before do
    driver.before
  end

  after do
    driver.after
  end

  it "renames columns for renamed tables" do
    # Load up columns to make them set table-name.
    test_table.columns.each do |name, column|
    end

    test_table.rename("test2")
    test_table.columns[:text].change(name: "text2")

    table = db.tables[:test2]
    column = table.columns[:text2]
    column.table.name.should eq :test2
  end

  it "should create columns right" do
    col_id = test_table.column(:id)
    col_id.type.should eq :int

    col_text = test_table.column(:text)
    col_text.type.should eq :varchar
  end
end