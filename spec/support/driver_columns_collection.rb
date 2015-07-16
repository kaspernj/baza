shared_examples_for "a baza columns driver" do
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

  it "should be able to change columns" do
    col_text = test_table.column(:text)
    col_text.change(name: "text2", type: :int, default: 5)

    col_text.type.should eq :int
    col_text.default.should eq "5"
    col_text.name.should eq :text2
  end

  it "should be able to drop a column" do
    test_table.column(:text).drop

    expect {
      test_table.column(:text)
    }.to raise_error(Errno::ENOENT)
  end
end
