shared_examples_for "a baza indexes driver" do
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

  it "renames indexes for renamed tables" do
    # Load up columns to make them set table-name.
    test_table.indexes.each do |name, index|
    end

    test_table.create_indexes([{name: "index_on_text", columns: [:text]}])
    test_table.rename("test2")

    test_table.index("index_on_text").rename("index_on_text2")

    table = db.tables[:test2]
    index = table.index(:index_on_text2)
    index.table.name.should eq :test2
  end

  it "should raise an error when index is not found" do
    expect {
      test_table.index("index_that_doesnt_exist")
    }.to raise_error(Errno::ENOENT)
  end
end
