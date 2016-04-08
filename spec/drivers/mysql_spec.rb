require "spec_helper"

describe Baza.const_get(:Driver).const_get(:Mysql) do
  let(:constant) do
    const_name = "InfoMysql"
    require "#{File.dirname(__FILE__)}/../#{StringCases.camel_to_snake(const_name)}"
    raise "Constant was not defined: '#{const_name}'." unless Baza.const_defined?(const_name)
    Baza.const_get(const_name)
  end

  it_should_behave_like "a baza driver"
  it_should_behave_like "a baza databases driver"
  it_should_behave_like "a baza tables driver"
  it_should_behave_like "a baza columns driver"
  it_should_behave_like "a baza indexes driver"
  it_should_behave_like "a baza users driver"

  it "should dump to sqlite3" do
    require "info_sqlite3"
    require "info_mysql"

    driver1 = Baza::InfoMysql.new
    db1 = driver1.db
    driver1.before

    driver2 = Baza::InfoSqlite3.new
    db2 = driver2.db
    driver2.before

    begin
      db1.tables.create(:test_table, columns: [
                          {name: :id, type: :int, autoincr: true, primarykey: true},
                          {name: :name, type: :varchar, maxlength: 100}
                        ])
      test_table = db1.tables[:test_table]


      db1.copy_to(db2)

      table_sqlite = db2.tables[:test_table]
      expect(table_sqlite.columns.length).to eq test_table.columns.length

      col_id_sqlite = table_sqlite.column(:id)
      expect(col_id_sqlite.type).to eq :int
      expect(col_id_sqlite.autoincr?).to eq true
      expect(col_id_sqlite.primarykey?).to eq true

      col_name_sqlite = table_sqlite.column(:name)
      expect(col_name_sqlite.type).to eq :varchar
      expect(col_name_sqlite.maxlength.to_i).to eq 100
    ensure
      driver1.after
      driver2.after
    end
  end
end
