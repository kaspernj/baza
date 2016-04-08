shared_examples_for "a baza columns driver" do
  let(:driver) { constant.new }
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

  it "renames columns for renamed tables" do
    test_table.columns # Load up columns to make them set table-name.

    test_table.rename("test2")
    test_table.column(:text).change(name: "text2")

    table = db.tables[:test2]
    column = table.column(:text2)
    expect(column.table.name).to eq "test2"
  end

  it "creates columns right" do
    col_id = test_table.column(:id)
    expect(col_id.type).to eq :int
    expect(col_id.primarykey?).to eq true
    expect(col_id.autoincr?).to eq true
    expect(col_id.default).to eq nil

    col_text = test_table.column(:text)
    expect(col_text.type).to eq :varchar
    expect(col_text.primarykey?).to eq false
    expect(col_text.autoincr?).to eq false
    expect(col_text.default).to eq nil
  end

  it "is able to change columns" do
    col_text = test_table.column(:text)
    col_text.change(name: "text2", type: :int, default: 5)

    expect(col_text.type).to eq :int
    expect(col_text.default).to eq "5"
    expect(col_text.name).to eq "text2"
  end

  it "is able to drop a column" do
    test_table.column(:text).drop

    expect do
      test_table.column(:text)
    end.to raise_error(Baza::Errors::ColumnNotFound)
  end
end
