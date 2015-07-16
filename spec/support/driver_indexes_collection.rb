shared_examples_for "a baza indexes driver" do
  let(:driver) { constant.new }
  let(:db) { driver.db }
  let(:test_table) do
    db.tables.create("test", {
      columns: [
        {name: "id", type: :int, autoincr: true, primarykey: true},
        {name: "text", type: :varchar},
        {name: "email", type: :varchar}
      ],
      indexes: [
        :text,
        {name: :email, unique: true, columns: [:email]}
      ]
    })
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
    index.table.name.should eq :test2
  end

  it "should raise an error when index is not found" do
    expect {
      test_table.index("index_that_doesnt_exist")
    }.to raise_error(Errno::ENOENT)
  end

  describe "#unique?" do
    it "returns true when it is unique" do
      test_table.index("email").unique?.should eq true
    end

    it "returns false when it isn't unique" do
      test_table.index("text").unique?.should eq false
    end
  end
end
