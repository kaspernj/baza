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
    rescue Baza::Errors::DatabaseNotFound
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
end
