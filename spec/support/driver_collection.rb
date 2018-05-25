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
    db.tables.create(
      "test",
      columns: [
        {name: "id", type: :int, autoincr: true, primarykey: true},
        {name: "text", type: :varchar},
        {name: "number", type: :int, default: 0},
        {name: "float", type: :float, default: 0.0},
        {name: "created_at", type: :datetime}
      ]
    )
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

  it "does id-queries" do
    test_table

    rows_count = 1250
    db.transaction do
      rows_count.times do |count|
        db.insert(:test, text: "User #{count}")
      end
    end

    block_ran = 0
    Baza::Idquery.new(db: db, debug: false, table: :test, query: "SELECT id FROM test") do
      block_ran += 1
    end

    expect(block_ran).to eq rows_count

    block_ran = 0
    db.select(:test, {}, idquery: true) do
      block_ran += 1
    end

    expect(block_ran).to eq rows_count
  end

  it "does unbuffered queries" do
    test_table

    10.times do |count|
      db.insert(:test, text: "Test #{count}")
    end

    count_results = 0
    db.query_ubuf("SELECT * FROM test") do |row|
      expect(row[:text]).to eq "Test #{count_results}"
      count_results += 1
    end

    expect(count_results).to eq 10
  end

  it "#upsert" do
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
    expect(row[:text]).to eq "upsert - Kasper Johansen"

    table.reload
    expect(table.rows_count).to eq rows_count + 1

    db.upsert(:test, data2, sel)
    row = db.select(:test, sel).fetch
    expect(row[:text]).to eq "upsert - Kasper Nielsen Johansen"

    table.reload
    expect(table.rows_count).to eq rows_count + 1
  end

  describe "#upsert_duplicate_key" do
    before do
      test_table.create_indexes([name: "unique_text", columns: ["text"], unique: true])
    end

    it "inserts records with terms" do
      expect(test_table.rows_count).to eq 0
      test_table.upsert_duplicate_key({number: 2}, text: "test1")
      expect(test_table.rows_count).to eq 1
    end

    it "updates existing records with terms" do
      test_table.insert(text: "test1", number: 1)
      test_table.upsert_duplicate_key({number: 2}, text: "test1")
      expect(test_table.rows_count).to eq 1

      rows = test_table.rows.to_a.map(&:to_hash)
      rows[0][:float] = "0.0" if rows[0][:float] == "0"
      expect(rows).to eq [{id: "1", text: "test1", number: "2", float: "0.0", created_at: ""}]
    end

    it "inserts with empty terms" do
      expect(test_table.rows_count).to eq 0
      id = test_table.upsert_duplicate_key({text: "test2"}, {}, return_id: true)
      expect(test_table.rows_count).to eq 1
      expect(id).to eq 1
    end

    it "updates existing records with empty terms" do
      test_table.insert(text: "test1", number: 1)
      id = test_table.upsert_duplicate_key({number: 2, text: "test1"}, {}, return_id: true)
      expect(test_table.rows_count).to eq 1
      expect(id).to eq 1
    end
  end

  it "dumps as SQL" do
    dump = Baza::Dump.new(db: db, debug: false)
    str_io = StringIO.new
    dump.dump(str_io)
    str_io.rewind

    # Remember some numbers for validation.
    tables_count = db.tables.list.length

    # Remove everything in the db.
    db.tables.list.select(&:native?).each(&:drop)

    # Run the exported SQL.
    db.transaction do
      str_io.each_line do |sql|
        db.q(sql)
      end
    end

    # Vaildate import.
    raise "Not same amount of tables: #{tables_count}, #{db.tables.list.length}" if tables_count != db.tables.list.length
  end

  it "generates proper sql" do
    time = Time.new(1985, 6, 17, 10, 30)
    expect(db.insert(:test, {date: time}, return_sql: true)).to eq "INSERT INTO #{db.sep_table}test#{db.sep_table} (#{db.sep_col}date#{db.sep_col}) VALUES (#{db.sep_val}1985-06-17 10:30:00#{db.sep_val})"

    date = Date.new(1985, 6, 17)
    expect(db.insert(:test, {date: date}, return_sql: true)).to eq "INSERT INTO #{db.sep_table}test#{db.sep_table} (#{db.sep_col}date#{db.sep_col}) VALUES (#{db.sep_val}1985-06-17#{db.sep_val})"
  end

  it "is able to make new connections based on given objects" do
    # Mysql doesn't support it...
    unless db.opts.fetch(:type) == :mysql
      Baza::Db.from_object(object: db.driver.conn)
    end
  end

  it "is able to do ID-queries through the select-method" do
    db.tables.create(
      :test_table,
      columns: [
        {name: :idrow, type: :int, autoincr: true, primarykey: true},
        {name: :name, type: :varchar}
      ]
    )

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

      expect(row[:name]).to eq "Kasper #{count_found}"
    end

    expect(count_found).to eq 10_000
  end

  it "uses query buffers" do
    db.tables.create(
      :test_table,
      columns: [
        {name: :id, type: :int, autoincr: true, primarykey: true},
        {name: :name, type: :varchar}
      ]
    )

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

        buffer.delete(:test_table, id: row.fetch(:id))

        next unless count == 1000
        time_end = Time.now.to_f

        time_spent = time_end - time_start
        raise "Too much time spent: '#{time_spent}'." if time_spent > 0.015
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
    db_with_type_translation.tables.create(
      :test,
      columns: [
        {name: "id", type: :int, autoincr: true, primarykey: true},
        {name: "text", type: :varchar},
        {name: "number", type: :int},
        {name: "float", type: :float},
        {name: "created_at", type: :datetime},
        {name: "date", type: :date}
      ]
    )

    db_with_type_translation.insert(:test, text: "Kasper", number: 30, float: 4.5, created_at: Time.now, date: Date.new(2015, 06, 17))

    row = db_with_type_translation.select(:test, text: "Kasper").fetch

    expect(row.fetch(:text).class).to eq String
    expect(row.fetch(:number).class.name).to eq "Fixnum"
    expect(row.fetch(:float).class).to eq Float

    if db.driver.conn.class.name == "ActiveRecord::ConnectionAdapters::SQLite3Adapter"
      check_time_and_date = false
    elsif db.driver.class.name == "Baza::Driver::ActiveRecord" && RUBY_PLATFORM == "java"
      check_time_and_date = false
    else
      check_time_and_date = true
    end

    if check_time_and_date
      expect(row.fetch(:created_at).class).to eq Time
      expect(row.fetch(:date).class).to eq Date
    end
  end

  it "returns arguments used to connect" do
    require_relative "../../lib/baza/driver/active_record"

    unless db.driver.is_a?(Baza::Driver::ActiveRecord)
      args = db.driver.class.args
      expect(args).to be_a Array
    end
  end

  it "#new_query" do
    test_table
    test_table.insert(text: "Kasper")

    query = db.new_query.from(:test).where(text: "Kasper").to_a
    query[0][:float] = query[0][:float].to_f.to_s if query[0][:float] == "0"
    expect(query.to_a).to eq [{id: "1", text: "Kasper", number: "0", float: "0.0", created_at: ""}]
  end

  it "#last_id" do
    test_table.insert(text: "Kasper")
    expect(db.last_id).to eq 1
  end

  it "handels null values for datetimes" do
    id = test_table.insert({text: "Kasper"}, return_id: true)
    row = test_table.row(id)
    expect(row[:created_at]).to eq ""
  end

  describe "#insert" do
    it "returns id" do
      test_table
      id = db.insert("test", {text: "Kasper"}, return_id: true)
      expect(id).to eq 1
    end
  end
end
