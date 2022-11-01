require "spec_helper"

describe Baza::Driver::Sqlite3 do
  let(:constant) do
    const_name = "InfoSqlite3"
    require "#{File.dirname(__FILE__)}/../#{StringCases.camel_to_snake(const_name)}"
    raise "Constant was not defined: '#{const_name}'." unless Baza.const_defined?(const_name)
    Baza.const_get(const_name)
  end

  it_behaves_like "a baza driver"
  it_behaves_like "a baza tables driver"
  it_behaves_like "a baza columns driver"
  it_behaves_like "a baza indexes driver"
  it_behaves_like "a baza importer driver"

  it "copies database structure and data" do
    require "info_sqlite3"
    db = Baza::InfoSqlite3.new.db
    db2 = Baza::InfoSqlite3.new.db

    db.tables.create(
      :test_table,
      columns: [
        {name: "id", type: :int, autoincr: true, primarykey: true},
        {name: "testname", type: :varchar, null: true}
      ],
      indexes: [
        "testname"
      ]
    )

    table1 = db.tables["test_table"]
    cols1 = table1.columns

    100.times do |count|
      table1.insert(testname: "TestRow#{count}")
    end

    expect { db2.tables[:test_table] }.to raise_error(Baza::Errors::TableNotFound)

    db.copy_to(db2)

    table2 = db2.tables[:test_table]

    cols2 = table2.columns
    expect(cols2.length).to eql(cols1.length)

    expect(table2.rows_count).to eq table1.rows_count

    db.select(:test_table) do |row1|
      found = 0
      db2.select(:test_table, row1) do |row2|
        found += 1

        row1.each do |key, val|
          expect(row2[key]).to eql(val)
        end
      end

      expect(found).to eq 1
    end

    expect(table1.indexes.length).to eq 1
    expect(table2.indexes.length).to eq table1.indexes.length
  end
end
