shared_examples_for "a baza importer driver" do
  let(:driver) { constant.new(debug: false) }
  let(:db) { driver.db }
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

  it "imports sql" do
    test_table

    io = StringIO.new
    dumper = Baza::Dump.new(db: db)
    dumper.dump(io)
    io.rewind

    test_table.drop

    importer = Baza::Commands::Importer.new(db: db, io: io)
    importer.execute

    expect(db.tables[:test].name).to eq "test"
  end
end
