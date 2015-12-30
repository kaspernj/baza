shared_examples_for "a baza driver" do
  let(:driver) { constant.new(type_translation: :string) }
  let(:driver2) { constant.new }
  let(:db) { driver.db }
  let(:db2) { driver2.db }
  let(:db_with_type_translation) { constant.new(type_translation: true, debug: false).db }
  let(:row) do
    test_table.insert(text: "Kasper", number: 30, float: 4.5)
    db.select(:test, text: "Kasper").fetch
  end
  let(:test_table) do
    db.tables.create("test", columns: [
      {name: "id", type: :int, autoincr: true, primarykey: true},
      {name: "text", type: :varchar},
      {name: "number", type: :int, default: 0},
      {name: "float", type: :float, default: 0.0}
    ])
    db.tables[:test]
  end

  before do
    driver.before
    driver2.before
  end

  after do
    driver.after
    driver2.after
  end

  it "should do revisions" do
    test_table

    schema = {
      tables: {
        test_table: {
          columns: [
            {name: "id", type: :int, autoincr: true, primarykey: true},
            {name: "name", type: :varchar},
            {name: "age", type: :int, default: 0},
            {name: "nickname", type: :varchar, default: ""}
          ],
          indexes: [
            "name"
          ],
          rows: [
            {
              find_by: {"id" => 1},
              data: {"id" => 1, "name" => "trala"}
            }
          ]
        }
      }
    }

    rev = Baza::Revision.new
    rev.init_db(schema: schema, debug: false, db: db)

    test_table = db.tables[:test_table]
    expect(test_table.columns.map(&:name)).to include "age"
    expect(test_table.columns.map(&:name)).to include "nickname"
  end

  it "does id-queries" do
    test_table

    rows_count = 1250
    db.transaction do
      0.upto(rows_count) do |count|
        db.insert(:test, text: "User #{count}")
      end
    end

    block_ran = 0
    idq = Baza::Idquery.new(db: db, debug: false, table: :test, query: "SELECT id FROM test") do |_data|
      block_ran += 1
    end

    raise "Block with should have ran too little: #{block_ran}." if block_ran < rows_count

    block_ran = 0
    db.select(:test, {}, idquery: true) do |_data|
      block_ran += 1
    end

    raise "Block with should have ran too little: #{block_ran}." if block_ran < rows_count
  end

  it "does unbuffered queries" do
    test_table

    10.times do |count|
      db.insert(:test, text: "Test #{count}")
    end

    count_results = 0
    db.q("SELECT * FROM test", type: :unbuffered) do |row|
      expect(row[:text]).to eq "Test #{count_results}"
      count_results += 1
    end

    expect(count_results).to eq 10
  end

  it "does upserting" do
    test_table.create_columns([{name: "nickname", type: :varchar}])

    # Test upserting.
    data = {text: "upsert - Kasper Johansen"}
    data2 = {text: "upsert - Kasper Nielsen Johansen"}
    sel = {nickname: "upsert - kaspernj"}

    table = db.tables[:test]
    table.reload
    rows_count = table.rows_count

    db.upsert(:test, data, sel)
    row = db.select(:test, sel).fetch
    row[:text].should eq "upsert - Kasper Johansen"

    table.reload
    table.rows_count.should eql(rows_count + 1)

    db.upsert(:test, data2, sel)
    row = db.select(:test, sel).fetch
    row[:text].should eq "upsert - Kasper Nielsen Johansen"

    table.reload
    table.rows_count.should eq rows_count + 1
  end

  it "dumps as SQL" do
    dump = Baza::Dump.new(db: db, debug: false)
    str_io = StringIO.new
    dump.dump(str_io)
    str_io.rewind

    # Remember some numbers for validation.
    tables_count = db.tables.list.length

    # Remove everything in the db.
    db.tables.list do |table|
      table.drop unless table.native?
    end

    # Run the exported SQL.
    db.transaction do
      str_io.each_line do |sql|
        db.q(sql)
      end
    end

    # Vaildate import.
    raise "Not same amount of tables: #{tables_count}, #{db.tables.list.length}" if tables_count != db.tables.list.length
  end

  it "renames tables in revisions" do
    test_table

    Baza::Revision.new.init_db(
      db: db,
      debug: false,
      schema: {
        tables: {
          new_test_table: {
            renames: [:test]
          }
        }
      }
    )

    tables = db.tables.list.map(&:name)

    expect(tables).to_not include "test"
    expect(tables).to include "new_test_table"
  end

  it "renames columns in revisions" do
    test_table

    Baza::Revision.new.init_db(
      db: db,
      debug: false,
      schema: {
        tables: {
          new_test_table: {
            columns: [
              {name: :new_name, type: :varchar, renames: [:text]}
            ]
          }
        }
      }
    )

    columns = db.tables[:new_test_table].columns.map(&:name)
    expect(columns).to_not include "text"
    expect(columns).to include "new_name"
  end

  it "generates proper sql" do
    time = Time.new(1985, 6, 17, 10, 30)
    db.insert(:test, {date: time}, return_sql: true).should eql("INSERT INTO `test` (`date`) VALUES ('1985-06-17 10:30:00')")

    date = Date.new(1985, 6, 17)
    db.insert(:test, {date: date}, return_sql: true).should eql("INSERT INTO `test` (`date`) VALUES ('1985-06-17')")
  end

  it "is able to make new connections based on given objects" do
    # Mysql doesn't support it...
    unless db.opts.fetch(:type) == :mysql
      new_db = Baza::Db.from_object(object: db.driver.conn)
    end
  end

  it "is able to do ID-queries through the select-method" do
    db.tables.create(:test_table, columns: [
      {name: :idrow, type: :int, autoincr: true, primarykey: true},
      {name: :name, type: :varchar}
    ])

    count = 0
    100.times do
      arr = []
      100.times do
        count += 1
        arr << {name: "Kasper #{count}"}
      end

      db.insert_multi(:test_table, arr)
    end

    count_found = 0
    db.select(:test_table, nil, idquery: :idrow) do |row|
      count_found += 1

      row[:name].should eq "Kasper #{count_found}"
    end

    expect(count_found).to eq 10_000
  end

  it "should be able to use query buffers" do
    db.tables.create(:test_table, columns: [
      {name: :id, type: :int, autoincr: true, primarykey: true},
      {name: :name, type: :varchar}
    ])

    upsert = false
    count_inserts = 0
    db.q_buffer do |buffer|
      2500.times do |count|
        if upsert
          buffer.upsert(:test_table, {name: "Kasper #{count}"}, name: "Kasper #{count}")
          upsert = false
        else
          buffer.insert(:test_table, name: "Kasper #{count}")
          upsert = true
        end

        count_inserts += 1
      end
    end

    expect(count_inserts).to eq 2500

    test_table = db.tables[:test_table]
    expect(test_table.rows_count).to eq 2500

    count = 0
    db.q_buffer do |buffer|
      upsert = false

      db.select(:test_table, {}, orderby: :id) do |row|
        expect(row[:name]).to eq "Kasper #{count}"

        if upsert
          buffer.upsert(:test_table, {name: "Kasper #{count}-#{count}"}, id: row.fetch(:id))
          upsert = false
        else
          buffer.update(:test_table, {name: "Kasper #{count}-#{count}"}, id: row.fetch(:id))
          upsert = true
        end

        count += 1
      end
    end

    expect(count).to eq 2500

    count = 0
    db.select(:test_table, {}, orderby: :id) do |row|
      expect(row[:name]).to eq "Kasper #{count}-#{count}"
      count += 1
    end

    expect(count).to eq 2500

    # Test the flush-async which flushes transactions in a thread asyncronous.
    db.q_buffer(flush_async: true) do |buffer|
      count = 0
      db.select(:test_table) do |row|
        count += 1

        time_start = Time.now.to_f if count == 1000

        buffer.delete(:test_table, id: row[:id])

        next unless count == 1000
        time_end = Time.now.to_f

        time_spent = time_end - time_start
        raise "Too much time spent: '#{time_spent}'." if time_spent > 0.01
      end
    end

    expect(test_table.rows_count).to eq 0
  end

  describe "results" do
    before do
      test_table.insert(text: "test 1")
      test_table.insert(text: "test 2")
    end

    it '#to_a' do
      array = db.select(:test).to_a
      expect(array.length).to eq 2
    end

    it '#to_a_enum' do
      array_enum = db.select(:test).to_a_enum
      count = 0
      array_enum.each { count += 1 }
      expect(count).to eq 2
      expect(array_enum.length).to eq 2
    end

    it '#to_enum' do
      enum = db.select(:test).to_enum

      count = 0
      enum.each { count += 1 }
      expect(count).to eq 2
    end
  end

  it "counts" do
    test_table.insert(text: "test 1")
    expect(db.count(:test, text: "test 1")).to eq 1
  end

  it "doesnt do type translation by default" do
    expect(row.fetch(:text).class).to eq String
    expect(row.fetch(:number).class).to eq String
    expect(row.fetch(:float).class).to eq String
  end

  it "does type translation" do
    db_with_type_translation.tables.create(:test, columns: [
      {name: "id", type: :int, autoincr: true, primarykey: true},
      {name: "text", type: :varchar},
      {name: "number", type: :int},
      {name: "float", type: :float},
      {name: "created_at", type: :datetime},
      {name: "date", type: :date}
    ])

    db_with_type_translation.insert(:test, text: "Kasper", number: 30, float: 4.5, created_at: Time.now, date: Date.new(2015, 06, 17))

    row = db_with_type_translation.select(:test, text: "Kasper").fetch

    expect(row.fetch(:text).class).to eq String
    expect(row.fetch(:number).class).to eq Fixnum
    expect(row.fetch(:float).class).to eq Float

    unless db.driver.conn.class.name == "ActiveRecord::ConnectionAdapters::SQLite3Adapter"
      expect(row.fetch(:created_at).class).to eq Time
      expect(row.fetch(:date).class).to eq Date
    end
  end
end
