shared_examples_for "a baza driver" do
  let(:constant){
    name = described_class.name.split("::").last
    const_name = "Info#{name.slice(0, 1).upcase}#{name.slice(1, name.length)}"
    require "#{File.dirname(__FILE__)}/../info_#{StringCases.camel_to_snake(name)}"
    raise "Constant was not defined: '#{const_name}'." unless Baza.const_defined?(const_name)
    Baza.const_get(const_name)
  }
  let(:driver){ constant.new }
  let(:driver2){ constant.new }
  let(:db){ driver.db }
  let(:db2){ driver2.db }
  let(:test_table){
    db.tables.create("test", {
      columns: [
        {name: "id", type: :int, autoincr: true, primarykey: true},
        {name: "text", type: :varchar}
      ]
    })
    db.tables[:test]
  }

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
    test_table.columns.keys.should include :age
    test_table.columns.keys.should include :nickname
  end

  it "should do id-queries" do
    test_table

    rows_count = 1250
    db.transaction do
      0.upto(rows_count) do |count|
        db.insert(:test, text: "User #{count}")
      end
    end

    block_ran = 0
    idq = Baza::Idquery.new(db: db, debug: false, table: :test, query: "SELECT id FROM test") do |data|
      block_ran += 1
    end

    raise "Block with should have ran too little: #{block_ran}." if block_ran < rows_count

    block_ran = 0
    db.select(:test, {}, idquery: true) do |data|
      block_ran += 1
    end

    raise "Block with should have ran too little: #{block_ran}." if block_ran < rows_count
  end

  it 'does unbuffered queries' do
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

  it "should do upserting" do
    test_table.create_columns([{name: "nickname", type: :varchar}])

    #Test upserting.
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

  it "should dump as SQL" do
    dump = Baza::Dump.new(db: db, debug: false)
    str_io = StringIO.new
    dump.dump(str_io)
    str_io.rewind

    #Remember some numbers for validation.
    tables_count = db.tables.list.length

    #Remove everything in the db.
    db.tables.list do |table|
      table.drop unless table.native?
    end

    #Run the exported SQL.
    db.transaction do
      str_io.each_line do |sql|
        db.q(sql)
      end
    end

    #Vaildate import.
    raise "Not same amount of tables: #{tables_count}, #{db.tables.list.length}" if tables_count != db.tables.list.length
  end

  it "should rename tables in revisions" do
    test_table

    Baza::Revision.new.init_db(db: db, debug: false, schema: {
      tables: {
        new_test_table: {
          renames: [:test]
        }
      }
    })
    tables = db.tables.list
    raise "Didnt expect table 'test' to exist but it did." if tables.key?(:test)
    raise "Expected 'new_test_table' to exist but it didnt." if !tables.key?(:new_test_table)
  end

  it "should rename columns in revisions" do
    test_table

    Baza::Revision.new.init_db(db: db, debug: false, schema: {
      tables: {
        new_test_table: {
          columns: [
            {name: :new_name, type: :varchar, renames: [:text]}
          ]
        }
      }
    })
    columns = db.tables[:new_test_table].columns
    raise "Didnt expect 'text' to exist but it did." if columns.key?(:text)
    raise "Expected 'new_name'-column to exist but it didnt." unless columns.key?(:new_name)
  end

  it "should generate proper sql" do
    time = Time.new(1985, 6, 17, 10, 30)
    db.insert(:test, {:date => time}, :return_sql => true).should eql("INSERT INTO `test` (`date`) VALUES ('1985-06-17 10:30:00')")

    date = Date.new(1985, 6, 17)
    db.insert(:test, {:date => date}, :return_sql => true).should eql("INSERT INTO `test` (`date`) VALUES ('1985-06-17')")
  end

  it "should be able to make new connections based on given objects" do
    # Mysql doesn't support it...
    unless db.opts.fetch(:type) == :mysql
      new_db = Baza::Db.from_object(object: db.conn.conn)
    end
  end

  it "should be able to do ID-queries through the select-method" do
    db.tables.create(:test_table, {
      :columns => [
        {:name => :idrow, :type => :int, :autoincr => true, :primarykey => true},
        {:name => :name, :type => :varchar}
      ]
    })

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
    db.select(:test_table, nil, :idquery => :idrow) do |row|
      count_found += 1

      row[:name].should eq "Kasper #{count_found}"
    end

    count_found.should eq 10000
  end

  it "should be able to use query buffers" do
    db.tables.create(:test_table, {
      :columns => [
        {:name => :id, :type => :int, :autoincr => true, :primarykey => true},
        {:name => :name, :type => :varchar}
      ]
    })

    upsert = false
    db.q_buffer do |buffer|
      2500.times do |count|
        if upsert
          buffer.upsert(:test_table, {:name => "Kasper #{count}"}, {:name => "Kasper #{count}"})
          upsert = false
        else
          buffer.insert(:test_table, {:name => "Kasper #{count}"})
          upsert = true
        end
      end
    end

    test_table = db.tables[:test_table]
    test_table.rows_count.should eql(2500)

    db.q_buffer do |buffer|
      count = 0
      upsert = false

      db.select(:test_table, {}, :orderby => :id) do |row|
        row[:name].should eql("Kasper #{count}")

        if upsert
          buffer.upsert(:test_table, {name: "Kasper #{count}-#{count}"}, {id: row[:id]})
          upsert = false
        else
          buffer.update(:test_table, {name: "Kasper #{count}-#{count}"}, {id: row[:id]})
          upsert = true
        end

        count += 1
      end
    end

    count = 0
    db.select(:test_table, {}, :orderby => :id) do |row|
      row[:name].should eq "Kasper #{count}-#{count}"
      count += 1
    end

    #Test the flush-async which flushes transactions in a thread asyncronous.
    db.q_buffer(:flush_async => true) do |buffer|
      count = 0
      db.select(:test_table) do |row|
        count += 1

        if count == 1000
          time_start = Time.now.to_f
        end

        buffer.delete(:test_table, id: row[:id])

        if count == 1000
          time_end = Time.now.to_f

          time_spent = time_end - time_start
          raise "Too much time spent: '#{time_spent}'." if time_spent > 0.01
        end
      end
    end

    test_table.rows_count.should eql(0)
  end

  describe 'results' do
    before do
      test_table.insert(text: 'test 1')
      test_table.insert(text: 'test 2')
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

  it 'counts' do
    test_table.insert(text: 'test 1')
    expect(db.count(:test, text: 'test 1')).to eq 1
  end
end
