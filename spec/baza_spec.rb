require File.expand_path(File.dirname(__FILE__) + '/spec_helper')

describe "Baza" do
  require "baza"
  require "knjrbfw"
  require "knj/os"
  require "rubygems"
  require "tmpdir"

  drivers = []
  Baza::Db.drivers.each do |driver_data|
    name = driver_data[:name].to_s
    const_name = "Info#{name.slice(0, 1).upcase}#{name.slice(1, name.length)}"
    require "#{File.dirname(__FILE__)}/info_#{driver_data[:name]}.rb"
    raise "Constant was not defined: '#{const_name}'." if !Baza.const_defined?(const_name)

    drivers << {
      :const => Baza.const_get(const_name),
    }
  end

  drivers.each do |driver|
    it "should be able to handle various encodings" do
      #I never got this test to actually fail... :-(
      debug = false

      driver[:const].sample_db do |db|
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
                {:name => "age", :type => :int, default: 0},
                {:name => "nickname", :type => :varchar, default: ""}
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

        db.upsert(:test_table, data, sel)
        row = db.select(:test_table, sel).fetch
        row[:name].should eql("upsert - Kasper Johansen")

        table.reload
        table.rows_count.should eql(rows_count + 1)

        db.upsert(:test_table, data2, sel)
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
      end
    end

    it "should generate proper sql" do
      driver[:const].sample_db do |db|
        time = Time.new(1985, 6, 17, 10, 30)
        db.insert(:test, {:date => time}, :return_sql => true).should eql("INSERT INTO `test` (`date`) VALUES ('1985-06-17 10:30:00')")

        date = Date.new(1985, 6, 17)
        db.insert(:test, {:date => date}, :return_sql => true).should eql("INSERT INTO `test` (`date`) VALUES ('1985-06-17')")
      end
    end

    it "should copy database structure and data" do
      driver[:const].sample_db do |db1|
        driver[:const].sample_db do |db2|
          db1.tables.create(:test_table, {
            :columns => [
              {:name => "id", :type => :int, :autoincr => true, :primarykey => true},
              {:name => "testname", :type => :varchar, null: true}
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

          begin
            table2 = db2.tables[:test_table]
            raise "Expected not-found exception."
          rescue Errno::ENOENT
            #expected
          end

          db1.copy_to(db2)

          table2 = db2.tables[:test_table]

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
      end
    end

    it "should be able to make new connections based on given objects" do
      driver[:const].sample_db do |db|
        db2 = Baza::Db.from_object(:object => db.conn.conn)
      end
    end

    it "should be able to do ID-queries through the select-method" do
      driver[:const].sample_db do |db|
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

        count_found.should eql(10000)
      end
    end

    it "should be able to use query buffers" do
      driver[:const].sample_db do |db|
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
              buffer.upsert(:test_table, {:name => "Kasper #{count}-#{count}"}, {:id => row[:id]})
              upsert = false
            else
              buffer.update(:test_table, {:name => "Kasper #{count}-#{count}"}, {:id => row[:id]})
              upsert = true
            end

            count += 1
          end
        end

        count = 0
        db.select(:test_table, {}, :orderby => :id) do |row|
          row[:name].should eql("Kasper #{count}-#{count}")
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

            buffer.delete(:test_table, {:id => row[:id]})

            if count == 1000
              time_end = Time.now.to_f

              time_spent = time_end - time_start
              raise "Too much time spent: '#{time_spent}'." if time_spent > 0.01
            end
          end
        end

        test_table.rows_count.should eql(0)
      end
    end
  end

  it "should be able to connect to mysql and do various stuff" do
    Baza::InfoSqlite3.sample_db do |db3|
      Baza::InfoMysql.sample_db do |db1|
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
  end
end
