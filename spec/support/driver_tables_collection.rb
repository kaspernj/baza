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

  it "creates tables" do
    expect(test_table.name).to eq "test"
    expect(db.tables[:test]).to_not eq nil
  end

  it "#list" do
    test_table
    expect(db.tables.list).to include test_table
  end

  it "#optimize" do
    test_table.optimize
    # FIXME: How to validate?
  end

  it "#truncate" do
    test_table

    db.insert(:test, text: "test")
    expect(db.select(:test).fetch.fetch(:id).to_i).to eq 1
    expect(test_table.rows_count).to eq 1

    # Throw out invalid encoding because it will make dumping fail.
    db.tables[:test].truncate
    expect(test_table.rows_count).to eq 0

    db.insert(:test, text: "test")
    expect(db.select(:test).fetch.fetch(:id).to_i).to eq 1
  end

  it "#clone" do
    test_table
    test_table.create_indexes([{name: "index_on_text", columns: ["text"]}])
    expect(test_table.indexes.length).to eq 1

    test_table.insert(text: "test1")
    test_table.insert(text: "test2")

    test_table.clone("test2")
    test_table2 = db.tables[:test2]

    expect(test_table2.columns.length).to eq test_table.columns.length
    expect(test_table2.indexes.length).to eq test_table.indexes.length
    expect(test_table2.rows_count).to eq test_table.rows_count
    expect(test_table2.rows_count).to eq 2
  end

  describe "#reload" do
    it "reloads the data on the table" do
      test_table.reload
      expect(test_table.name).to eq "test"

      test_table.drop
      expect { test_table.reload }.to raise_error(Baza::Errors::TableNotFound)
    end
  end
end
