shared_examples_for "a baza tables driver" do
  let(:driver) { constant.new }
  let(:driver2) { constant.new }
  let(:db) { driver.db }
  let(:db2) { driver2.db }
  let(:test_table) do
    db.tables.create(
      "test",
      columns: [
        {name: "id", type: :int, autoincr: true, primarykey: true},
        {name: "text", type: :varchar}
      ]
    )
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
    expect(db.tables[:test].name).to eq "test"
  end

  describe "#exists?" do
    it "returns true for tables that exists" do
      test_table
      expect(db.tables.exists?("test")).to be true
    end

    it "returns false for tables that doesnt exist" do
      expect(db.tables.exists?("testtest")).to be false
    end
  end

  it "#list" do
    test_table
    expect(db.tables.list).to include test_table
  end

  it "#optimize" do
    test_table.optimize
    # FIXME: How to validate?
  end

  it "#rows_count" do
    expect(test_table.rows_count).to eq 0
    test_table.insert(text: "Test")
    expect(test_table.rows_count).to eq 1
  end

  it "#native?" do
    expect(test_table.native?).to be false
  end

  it "#row" do
    expect { test_table.row(500) }.to raise_error(Baza::Errors::RowNotFound)
    test_table.insert(id: 1, text: "Test")
    expect(test_table.row(1)[:text]).to eq "Test"
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

  describe "#foreign_keys" do
    it "adds a foreign key on table creation" do
      db.query("PRAGMA foreign_keys = ON") if db.sqlite?

      db.tables.create(
        :users,
        columns: [
          {name: :id, type: :int, autoincr: true, primarykey: true},
          {name: :name, type: :varchar}
        ]
      )
      db.tables.create(
        :comments,
        columns: [
          {name: :id, type: :int, autoincr: true, primarykey: true},
          {name: :comment, type: :text},
          {name: :user_id, type: :int, foreign_key: {to: [:users, :id]}}
        ]
      )

      foreign_keys = db.tables[:comments].foreign_keys
      foreign_key = foreign_keys.first

      expect(foreign_keys).to have_attributes(length: 1)
      expect(foreign_key).to have_attributes(
        column_name: "user_id",
        table_name: "comments"
      )
    end

    it "adds a foreign key after table is created" do
      unless db.sqlite?
        db.tables.create(
          :users,
          columns: [
            {name: :id, type: :int, autoincr: true, primarykey: true},
            {name: :name, type: :varchar}
          ]
        )
        db.tables.create(
          :comments,
          columns: [
            {name: :id, type: :int, autoincr: true, primarykey: true},
            {name: :comment, type: :text},
            {name: :user_id, type: :int}
          ]
        )
        db.foreign_keys.create(
          from: [:comments, :user_id],
          to: [:users, :id]
        )

        foreign_keys = db.tables[:comments].foreign_keys
        foreign_key = foreign_keys.first

        expect(foreign_keys).to have_attributes(length: 1)
        expect(foreign_key).to have_attributes(
          column_name: "user_id",
          table_name: "comments"
        )
      end
    end
  end

  describe "#reload" do
    it "reloads the data on the table" do
      test_table.reload
      expect(test_table.name).to eq "test"

      test_table.drop
      expect { test_table.reload }.to raise_error(Baza::Errors::TableNotFound)
    end
  end

  describe "Baza::Table#rows_count" do
    it "returns the number of rows in the table" do
      3.times { |n| test_table.insert(text: "Test #{n}") }
      expect(test_table.rows_count).to eq 3
    end
  end
end
