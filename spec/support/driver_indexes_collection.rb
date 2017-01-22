shared_examples_for "a baza indexes driver" do
  let(:driver) { constant.new }
  let(:db) { driver.db }
  let(:test_table) do
    db.tables.create(
      "test",
      columns: [
        {name: "id", type: :int, autoincr: true, primarykey: true},
        {name: "text", type: :varchar},
        {name: "email", type: :varchar}
      ],
      indexes: [
        :text,
        {name: :email, unique: true, columns: [:email]},
        {name: :two_columns, columns: [:text, :email]}
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

  it "renames indexes for renamed tables" do
    # Load up columns to make them set table-name.
    test_table.indexes.each do |name, index|
    end

    test_table.create_indexes([{name: "index_on_text", columns: [:text]}])
    test_table.rename("test2")
    test_table.index("index_on_text").rename("index_on_text2")

    table = db.tables[:test2]
    index = table.index(:index_on_text2)
    expect(index.table.name).to eq "test2"
  end

  it "raises an error when an index isn't found" do
    expect do
      test_table.index("index_that_doesnt_exist")
    end.to raise_error(Baza::Errors::IndexNotFound)
  end

  describe Baza::Index do
    describe "#unique?" do
      it "returns true when it is unique" do
        expect(test_table.index("email").unique?).to eq true
      end

      it "returns false when it isn't unique" do
        expect(test_table.index("text").unique?).to eq false
      end
    end

    describe "#columns" do
      it "returns the correct columns" do
        expect(test_table.index("two_columns").columns).to eq %w(text email)
      end
    end
  end
end
