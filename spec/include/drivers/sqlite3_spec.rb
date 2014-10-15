require "spec_helper"

describe Baza::Driver::Sqlite3 do
  it_behaves_like "a baza driver"
  it_should_behave_like "a baza tables driver"
  it_should_behave_like "a baza columns driver"
  it_should_behave_like "a baza indexes driver"

  it "should copy database structure and data" do
    require "info_sqlite3"
    db = Baza::InfoSqlite3.new.db
    db2 = Baza::InfoSqlite3.new.db

    db.tables.create(:test_table, {
      columns: [
        {name: "id", type: :int, autoincr: true, primarykey: true},
        {name: "testname", type: :varchar, null: true}
      ],
      indexes: [
        "testname"
      ]
    })

    table1 = db.tables["test_table"]
    cols1 = table1.columns

    100.times do |count|
      table1.insert(testname: "TestRow#{count}")
    end

    expect {
      table2 = db2.tables[:test_table]
    }.to raise_error(Errno::ENOENT)

    db.copy_to(db2)

    table2 = db2.tables[:test_table]

    cols2 = table2.columns
    cols2.length.should eql(cols1.length)

    table2.rows_count.should eql(table1.rows_count)

    db.select(:test_table) do |row1|
      found = 0
      db2.select(:test_table, row1) do |row2|
        found += 1

        row1.each do |key, val|
          row2[key].should eql(val)
        end
      end

      found.should eq 1
    end

    table1.indexes.length.should eq 1
    table2.indexes.length.should eq table1.indexes.length
  end
end
