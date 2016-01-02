shared_examples_for "a baza databases driver" do
  let(:driver) { constant.new }
  let(:driver2) { constant.new }
  let(:db) { driver.db }
  let(:db2) { driver2.db }
  let(:test_database) do
    db.databases.create(name: "baza-test-create", if_not_exists: true)
    db.databases["baza-test-create"]
  end

  it "renames database" do
    begin
      db.databases["renamed-db"].drop
    # rubocop:disable Lint/HandleExceptions
    rescue Baza::Errors::DatabaseNotFound
      # rubocop:enable Lint/HandleExceptions
      # Ignore - it shouldn't exist
    end

    test_database.name = "renamed-db"
    test_database.save!

    expect(test_database.name).to eq "renamed-db"
  end

  it "drops databases" do
    test_database.drop
    expect { db.databases["baza-test-create"] }.to raise_error(Baza::Errors::DatabaseNotFound)
  end

  it "creates tables" do
    if test_database.table_exists?("test")
      puts "DROPPING TEST TABLE"
      test_database.table("test").drop
    end

    test_database.create_table(
      "test",
      columns: [
        {name: :id, type: :int, autoincr: true, primarykey: true},
        {name: :name, type: :varchar}
      ]
    )

    tables = test_database.tables.map(&:name).to_a
    expect(tables).to eq ["test"]

    table = test_database.table("test")
    expect(table.name).to eq "test"
  end
end
