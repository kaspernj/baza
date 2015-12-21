shared_examples_for "a baza tables driver" do
  let(:driver) { constant.new }
  let(:driver2) { constant.new }
  let(:db) { driver.db }
  let(:db2) { driver2.db }
  let(:test_table) do
    db.tables.create("test", columns: [
      {name: "id", type: :int, autoincr: true, primarykey: true},
      {name: "text", type: :varchar}
    ])
    db.tables[:test]
  end

  before do
    driver.before
  end

  after do
    driver.after
  end

  it "should create tables" do
    test_table.name.should eq :test
    db.tables[:test].should_not eq nil
  end

  it "should list tables" do
    test_table
    db.tables.list.values.should include test_table
  end

  it "should optimize tables" do
    test_table.optimize
    # FIXME: How to validate?
  end

  it "should truncate tables" do
    test_table

    db.insert(:test, text: "test")
    test_table.rows_count.should eq 1

    # Throw out invalid encoding because it will make dumping fail.
    db.tables[:test].truncate
    test_table.rows_count.should eq 0
  end

  it "#clone" do
    test_table
    test_table.create_indexes([{name: "index_on_text", columns: ["text"]}])
    test_table.indexes.length.should eq 1

    test_table.insert(text: "test1")
    test_table.insert(text: "test2")

    test_table.clone("test2")
    test_table2 = db.tables[:test2]

    test_table2.columns.length.should eq test_table.columns.length
    test_table2.indexes.length.should eq test_table.indexes.length
    test_table2.rows_count.should eq test_table.rows_count
    test_table2.rows_count.should eq 2
  end
end
