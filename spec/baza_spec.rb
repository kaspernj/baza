require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Baza" do
  MYSQL_CONF_FILE = "#{File.dirname(__FILE__)}/mysql_info.rb"
  
  it "should be able to handle various encodings" do
    #I never got this test to actually fail... :-(
    debug = false
    
    require "baza"
    require "knjrbfw"
    require "knj/os"
    require "rubygems"
    require "sqlite3" if !Kernel.const_defined?("SQLite3") and RUBY_ENGINE != "jruby"
    
    db_path = "#{Knj::Os.tmpdir}/knjrbfw_test_sqlite3.sqlite3"
    File.unlink(db_path) if File.exists?(db_path)
    
    db = Baza::Db.new(
      :type => "sqlite3",
      :path => db_path,
      :return_keys => "symbols",
      :index_append_table_name => true
    )
    
    db.tables.create("test", {
      :columns => [
        {:name => "id", :type => :int, :autoincr => true, :primarykey => true},
        {:name => "text", :type => :varchar}
      ]
    })
    
    
    
    #Get a list of tables and check the list for errors.
    list = db.tables.list
    raise "Table not found: 'test'." if !list.key?(:test)
    
    list[:test].name.should eql(:test)
    
    
    #Test revision to create tables, indexes and insert rows.
    schema = {
      :tables => {
        :test_table => {
          :columns => [
            {:name => "id", :type => :int, :autoincr => true, :primarykey => true},
            {:name => "name", :type => :varchar},
            {:name => "age", :type => :int},
            {:name => "nickname", :type => :varchar}
          ],
          :indexes => [
            "name"
          ],
          :rows => [
            {
              :find_by => {"id" => 1},
              :data => {"id" => 1, "name" => "trala"}
            }
          ]
        }
      }
    }
    
    rev = Baza::Revision.new
    rev.init_db(:schema => schema, :debug => debug, :db => db)
    
    test_table = db.tables[:test_table]
    
    
    #Test wrong encoding.
    cont = File.read("#{File.dirname(__FILE__)}/db_spec_encoding_test_file.txt")
    cont.force_encoding("ASCII-8BIT")
    
    db.insert("test", {
      "text" => cont
    })
    
    
    #Throw out invalid encoding because it will make dumping fail.
    db.tables[:test].truncate
    
    
    
    #Test IDQueries.
    rows_count = 1250
    db.transaction do
      0.upto(rows_count) do |count|
        db.insert(:test_table, {:name => "User #{count}"})
      end
    end
    
    block_ran = 0
    idq = Baza::Idquery.new(:db => db, :debug => debug, :table => :test_table, :query => "SELECT id FROM test_table") do |data|
      block_ran += 1
    end
    
    raise "Block with should have ran too little: #{block_ran}." if block_ran < rows_count
    
    block_ran = 0
    db.select(:test_table, {}, {:idquery => true}) do |data|
      block_ran += 1
    end
    
    raise "Block with should have ran too little: #{block_ran}." if block_ran < rows_count
    
    
    #Test upserting.
    data = {:name => "upsert - Kasper Johansen"}
    data2 = {:name => "upsert - Kasper Nielsen Johansen"}
    sel = {:nickname => "upsert - kaspernj"}
    
    table = db.tables[:test_table]
    table.reload
    rows_count = table.rows_count
    
    db.upsert(:test_table, sel, data)
    row = db.select(:test_table, sel).fetch
    row[:name].should eql("upsert - Kasper Johansen")
    
    table.reload
    table.rows_count.should eql(rows_count + 1)
    
    db.upsert(:test_table, sel, data2)
    row = db.select(:test_table, sel).fetch
    row[:name].should eql("upsert - Kasper Nielsen Johansen")
    
    table.reload
    table.rows_count.should eql(rows_count + 1)
    
    
    #Test dumping.
    dump = Baza::Dump.new(:db => db, :debug => false)
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
    
    
    
    #Test revision table renaming.
    Baza::Revision.new.init_db(:db => db, :debug => debug, :schema => {
      :tables => {
        :new_test_table => {
          :renames => [:test_table]
        }
      }
    })
    tables = db.tables.list
    raise "Didnt expect table 'test_table' to exist but it did." if tables.key?(:test_table)
    raise "Expected 'new_test_table' to exist but it didnt." if !tables.key?(:new_test_table)
    
    
    #Test revision for column renaming.
    Baza::Revision.new.init_db(:db => db, :debug => debug, :schema => {
      :tables => {
        :new_test_table => {
          :columns => [
            {:name => :new_name, :type => :varchar, :renames => [:name]}
          ]
        }
      }
    })
    columns = db.tables[:new_test_table].columns
    raise "Didnt expect 'name' to exist but it did." if columns.key?(:name)
    raise "Expected 'new_name'-column to exist but it didnt." if !columns.key?(:new_name)
    
    
    #Delete test-database if everything went well.
    File.unlink(db_path) if File.exists?(db_path)
  end
  
  it "should generate proper sql" do
    require "knj/db"
    require "knj/os"
    require "rubygems"
    require "sqlite3" if !Kernel.const_defined?("SQLite3") and RUBY_ENGINE != "jruby"
    
    db_path = "#{Knj::Os.tmpdir}/knjrbfw_test_sqlite3.sqlite3"
    File.unlink(db_path) if File.exists?(db_path)
    
    db = Baza::Db.new(
      :type => "sqlite3",
      :path => db_path,
      :return_keys => "symbols",
      :index_append_table_name => true
    )
    
    time = Time.new(1985, 6, 17, 10, 30)
    db.insert(:test, {:date => time}, :return_sql => true).should eql("INSERT INTO `test` (`date`) VALUES ('1985-06-17 10:30:00')")
    
    date = Date.new(1985, 6, 17)
    db.insert(:test, {:date => date}, :return_sql => true).should eql("INSERT INTO `test` (`date`) VALUES ('1985-06-17')")
  end
  
  it "should copy database structure and data" do
    require "knj/db"
    require "knj/os"
    require "rubygems"
    require "sqlite3" if !Kernel.const_defined?("SQLite3") and RUBY_ENGINE != "jruby"
    
    db_path1 = "#{Knj::Os.tmpdir}/knjrbfw_test_sqlite3_db1.sqlite3"
    File.unlink(db_path1) if File.exists?(db_path1)
    
    db_path2 = "#{Knj::Os.tmpdir}/knjrbfw_test_sqlite3_db2.sqlite3"
    File.unlink(db_path2) if File.exists?(db_path2)
    
    db1 = Baza::Db.new(
      :type => "sqlite3",
      :path => db_path1,
      :return_keys => "symbols",
      :index_append_table_name => true
    )
    
    db1.tables.create(:test_table, {
      :columns => [
        {:name => "id", :type => :int, :autoincr => true, :primarykey => true},
        {:name => "testname", :type => :varchar}
      ],
      :indexes => [
        "testname"
      ]
    })
    
    table1 = db1.tables["test_table"]
    cols1 = table1.columns
    
    100.times do |count|
      table1.insert(:testname => "TestRow#{count}")
    end
    
    db2 = Baza::Db.new(
      :type => "sqlite3",
      :path => db_path2,
      :return_keys => "symbols",
      :index_append_table_name => true
    )
    
    begin
      table2 = db2.tables["test_table"]
      raise "Expected not-found exception."
    rescue Errno::ENOENT
      #expected
    end
    
    db1.copy_to(db2)
    
    table2 = db2.tables["test_table"]
    
    cols2 = table2.columns
    cols2.length.should eql(cols1.length)
    
    table2.rows_count.should eql(table1.rows_count)
    
    db1.select(:test_table) do |row1|
      found = 0
      db2.select(:test_table, row1) do |row2|
        found += 1
        
        row1.each do |key, val|
          row2[key].should eql(val)
        end
      end
      
      found.should eql(1)
    end
    
    table1.indexes.length.should eql(1)
    table2.indexes.length.should eql(table1.indexes.length)
  end
  
  it "should be able to make new connections based on given objects" do
    path = "#{Knj::Os.tmpdir}/baza_db_from_conn"
    
    db = Baza::Db.new(
      :type => "sqlite3",
      :path => path
    )
    
    sqlite_conn = db.conn.conn
    
    db2 = Baza::Db.from_object(:object => sqlite_conn)
  end
  
  it "should be able to connect to mysql and do various stuff" do
    require MYSQL_CONF_FILE
    db1 = Baza::Db.new($mysql_info.merge(
      :type => "mysql",
      :subtype => "mysql2",
    ))
    
    begin
      test_table = db1.tables[:test_table]
      test_table.drop
    rescue Errno::ENOENT
      #ignore
    end
    
    #create table.
    db1.tables.create(:test_table, {
      :columns => [
        {:name => :id, :type => :int, :autoincr => true, :primarykey => true},
        {:name => :name, :type => :varchar, :maxlength => 100}
      ]
    })
    
    test_table = db1.tables[:test_table]
    
    col_id = test_table.column(:id)
    col_name = test_table.column(:name)
    
    #Test various operations actually work.
    test_table.optimize
    
    #object_from test
    db2 = Baza::Db.from_object(db1.conn.conn)
    
    #Test dumping to SQLite.
    path = "#{Dir.tmpdir}/baza_mysql_dump_to_sqlite.sqlite3"
    File.unlink(path) if File.exists?(path)
    db3 = Baza::Db.new(:type => :sqlite3, :path => path)
    db2.copy_to(db3)
    
    table_sqlite = db3.tables[:test_table]
    table_sqlite.columns.length.should eql(test_table.columns.length)
    
    col_id_sqlite = table_sqlite.column(:id)
    col_id_sqlite.type.should eql(:int)
    col_id_sqlite.autoincr?.should eql(true)
    col_id_sqlite.primarykey?.should eql(true)
    
    col_name_sqlite = table_sqlite.column(:name)
    col_name_sqlite.type.should eql(:varchar)
    col_name_sqlite.maxlength.to_i.should eql(100)
  end
end
