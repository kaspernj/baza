#This class takes a database-schema from a hash and runs it against the database. It then checks that the database matches the given schema.
#
#===Examples
# db = Baza::Db.new(:type => "sqlite3", :path => "test_db.sqlite3")
# schema = {
#   "tables" => {
#     "User" => {
#       "columns" => [
#         {"name" => "id", "type" => "int", "autoincr" => true, "primarykey" => true},
#         {"name" => "name", "type" => "varchar"},
#         {"name" => "lastname", "type" => "varchar"}
#       ],
#       "indexes" => [
#         "name",
#         {"name" => "lastname", "columns" => ["lastname"]}
#       ],
#       "on_create_after" => proc{|d|
#         d["db"].insert("User", {"name" => "John", "lastname" => "Doe"})
#       }
#     }
#   }
# }
# 
# rev = Baza::Revision.new
# rev.init_db("db" => db, "schema" => schema)
class Baza::Revision
  def initialize(args = {})
    @args = args
  end
  
  INIT_DB_ALLOWED_ARGS = [:db, :schema, :tables_cache, :debug]
  INIT_DB_SCHEMA_ALLOWED_ARGS = [:tables]
  INIT_DB_TABLE_ALLOWED_ARGS = [:columns, :indexes, :rows, :renames]
  #This initializes a database-structure and content based on a schema-hash.
  #===Examples
  # dbrev = Baza::Revision.new
  # dbrev.init_db("db" => db_obj, "schema" => schema_hash)
  def init_db(args)
    args.each do |key, val|
      raise "Invalid key: '#{key}' (#{key.class.name})." unless INIT_DB_ALLOWED_ARGS.include?(key)
    end
    
    schema = args[:schema]
    db = args[:db]
    
    schema.each do |key, val|
      raise "Invalid key for schema: '#{key}' (#{key.class.name})." unless INIT_DB_SCHEMA_ALLOWED_ARGS.include?(key)
    end
    
    #Check for normal bugs and raise apropiate error.
    raise "'schema' argument was not a Hash: '#{schema.class.name}'." if !schema.is_a?(Hash)
    raise "No tables given." if !schema.has_key?(:tables)
    
    #Cache tables to avoid constant reloading.
    if !args.key?(:tables_cache) or args[:tables_cache]
      puts "Caching tables-list." if args[:debug]
      tables = db.tables.list
    else
      puts "Skipping tables-cache." if args[:debug]
    end
    
    schema[:tables].each do |table_name, table_data|
      table_data.each do |key, val|
        raise "Invalid key: '#{key}' (#{key.class.name})." unless INIT_DB_TABLE_ALLOWED_ARGS.include?(key)
      end
      
      begin
        begin
          table_name = table_name.to_sym
          
          puts "Getting table-object for table: '#{table_name}'." if args[:debug]
          table_obj = db.tables[table_name]
          
          #Cache indexes- and column-objects to avoid constant reloading.
          cols = table_obj.columns
          indexes = table_obj.indexes
          
          if table_data[:columns]
            first_col = true
            table_data[:columns].each do |col_data|
              begin
                col_name = col_data[:name].to_sym
                col_obj = table_obj.column(col_name)
                col_str = "#{table_name}.#{col_obj.name}"
                type = col_data[:type].to_sym
                dochange = false
                
                if !first_col and !col_data[:after]
                  #Try to find out the previous column - if so we can set "after" which makes the column being created in the right order as defined.
                  if !col_data.has_key?(:after)
                    prev_no = table_data[:columns].index(col_data)
                    if prev_no != nil and prev_no != 0
                      prev_no = prev_no - 1
                      prev_col_data = table_data[:columns][prev_no]
                      col_data[:after] = prev_col_data[:name]
                    end
                  end
                  
                  actual_after = nil
                  set_next = false
                  cols.each do |col_name, col_iter|
                    if col_iter.name == col_obj.name
                      break
                    else
                      actual_after = col_iter.name
                    end
                  end
                  
                  if actual_after != col_data[:after]
                    print "Changing '#{col_str}' after from '#{actual_after}' to '#{col_data[:after]}'.\n" if args[:debug]
                    dochange = true
                  end
                end
                
                #BUGFIX: When using SQLite3 the primary-column or a autoincr-column may never change type from int... This will break it!
                if db.opts[:type] == "sqlite3" and col_obj.type.to_s == "int" and (col_data[:primarykey] or col_data[:autoincr]) and db.int_types.index(col_data[:type].to_s)
                  type = :int
                end
                
                if type and col_obj.type.to_s != type
                  print "Type mismatch on #{col_str}: #{col_data[:type]}, #{col_obj.type}\n" if args[:debug]
                  dochange = true
                end
                
                if col_data.has_key?(:primarykey) and col_obj.primarykey? != col_data[:primarykey]
                  print "Primary-key mismatch for #{col_str}: #{col_data[:primarykey]}, #{col_obj.primarykey?}\n" if args[:debug]
                  dochange = true
                end
                
                if col_data.has_key?(:autoincr) and col_obj.autoincr? != col_data[:autoincr]
                  print "Auto-increment mismatch for #{col_str}: #{col_data[:autoincr]}, #{col_obj.autoincr?}\n" if args[:debug]
                  dochange = true
                end
                
                if col_data.has_key?(:maxlength) and col_obj.maxlength.to_s != col_data[:maxlength].to_s
                  print "Maxlength mismatch on #{col_str}: #{col_data[:maxlength]}, #{col_obj.maxlength}\n" if args[:debug]
                  dochange = true
                end
                
                if col_data.has_key?(:null) and col_obj.null?.to_s != col_data[:null].to_s
                  print "Null mismatch on #{col_str}: #{col_data[:null]}, #{col_obj.null?}\n" if args[:debug]
                  dochange = true
                end
                
                if col_data.has_key?(:default) and col_obj.default.to_s != col_data[:default].to_s
                  print "Default mismatch on #{col_str}: #{col_data[:default]}, #{col_obj.default}\n" if args[:debug]
                  dochange = true
                end
                
                if col_data.has_key?(:comment) and col_obj.respond_to?(:comment) and col_obj.comment.to_s != col_data[:comment].to_s
                  print "Comment mismatch on #{col_str}: #{col_data[:comment]}, #{col_obj.comment}\n" if args[:debug]
                  dochange = true
                end
                
                if col_data.is_a?(Hash) and col_data[:on_before_alter]
                  callback_data = col_data[:on_before_alter].call(:db => db, :table => table_obj, :col => col_obj, :col_data => col_data)
                  if callback_data and callback_data[:action]
                    if callback_data[:action] == :retry
                      raise Knj::Errors::Retry
                    end
                  end
                end
                
                if dochange
                  col_obj.change(col_data)
                  
                  #Change has been made - update cache.
                  cols = table_obj.columns
                end
                
                first_col = false
              rescue Errno::ENOENT => e
                print "Column not found: #{table_obj.name}.#{col_data[:name]}.\n" if args[:debug]
                
                if col_data.has_key?(:renames)
                  raise "'renames' was not an array for column '#{table_obj.name}.#{col_data[:name]}'." if !col_data[:renames].is_a?(Array)
                  
                  rename_found = false
                  col_data[:renames].each do |col_name|
                    begin
                      col_rename = table_obj.column(col_name)
                    rescue Errno::ENOENT => e
                      next
                    end
                    
                    print "Rename #{table_obj.name}.#{col_name} to #{table_obj.name}.#{col_data[:name]}\n" if args[:debug]
                    if col_data.is_a?(Hash) and col_data[:on_before_rename]
                      col_data[:on_before_rename].call(:db => db, :table => table_obj, :col => col_rename, :col_data => col_data)
                    end
                    
                    col_rename.change(col_data)
                    
                    #Change has been made - update cache.
                    cols = table_obj.columns
                    
                    if col_data.is_a?(Hash) and col_data[:on_after_rename]
                      col_data[:on_after_rename].call(:db => db, :table => table_obj, :col => col_rename, :col_data => col_data)
                    end
                    
                    rename_found = true
                    break
                  end
                  
                  retry if rename_found
                end
                
                oncreated = col_data[:on_created]
                col_data.delete(:on_created) if col_data[:oncreated]
                
                col_data_create = col_data
                col_data_create.delete(:renames)
                
                col_obj = table_obj.create_columns([col_data])
                
                #Change has been made - update cache.
                cols = table_obj.columns
                
                oncreated.call(:db => db, :table => table_obj) if oncreated
              end
            end
          end
          
          if table_data[:columns_remove]
            table_data[:columns_remove].each do |column_name, column_data|
              begin
                col_obj = table_obj.column(column_name)
              rescue Errno::ENOENT => e
                next
              end
              
              column_data[:callback].call if column_data.is_a?(Hash) and column_data[:callback]
              col_obj.drop
            end
          end
          
          if table_data[:indexes]
            table_data[:indexes].each do |index_data|
              if index_data.is_a?(String)
                index_data = {:name => index_data, :columns => [index_data]}
              end
              
              begin
                index_obj = table_obj.index(index_data[:name])
                
                rewrite_index = false
                rewrite_index = true if index_data.key?(:unique) and index_data[:unique] != index_obj.unique?
                
                if rewrite_index
                  index_obj.drop
                  table_obj.create_indexes([index_data])
                end
              rescue Errno::ENOENT => e
                table_obj.create_indexes([index_data])
              end
            end
          end
          
          if table_data[:indexes_remove]
            table_data[:indexes_remove].each do |index_name, index_data|
              begin
                index_obj = table_obj.index(index_name)
              rescue Errno::ENOENT => e
                next
              end
              
              if index_data.is_a?(Hash) and index_data[:callback]
                index_data[:callback].call if index_data[:callback]
              end
              
              index_obj.drop
            end
          end
          
          rows_init(:db => db, :table => table_obj, :rows => table_data[:rows]) if table_data and table_data[:rows]
        rescue Errno::ENOENT => e
          puts "Table did not exist: '#{table_name}'." if args[:debug]
          
          if table_data.key?(:renames)
            table_data[:renames].each do |table_name_rename|
              begin
                puts "Renaming table: '#{table_name_rename}' to '#{table_name}'." if args[:debug]
                table_rename = db.tables[table_name_rename.to_sym]
                table_rename.rename(table_name)
                raise Knj::Errors::Retry
              rescue Errno::ENOENT
                next
              end
            end
          end
          
          if !table_data.key?(:columns)
            print "Notice: Skipping creation of '#{table_name}' because no columns were given in hash.\n"
            next
          end
          
          if table_data[:on_create]
            table_data[:on_create].call(:db => db, :table_name => table_name, :table_data => table_data)
          end
          
          table_data_create = table_data.clone
          table_data_create.delete(:rows)
          
          puts "Creating table: '#{table_name}'." if args[:debug]
          db.tables.create(table_name, table_data_create)
          table_obj = db.tables[table_name.to_sym]
          
          if table_data[:on_create_after]
            table_data[:on_create_after].call(:db => db, :table_name => table_name, :table_data => table_data)
          end
          
          rows_init(:db => db, :table => table_obj, :rows => table_data[:rows]) if table_data[:rows]
        end
      rescue Knj::Errors::Retry
        retry
      end
    end
    
    if schema[:tables_remove]
      schema[:tables_remove].each do |table_name, table_data|
        begin
          table_obj = db.tables[table_name.to_sym]
          table_data[:callback].call(:db => db, :table => table_obj) if table_data.is_a?(Hash) and table_data[:callback]
          table_obj.drop
        rescue Errno::ENOENT => e
          next
        end
      end
    end
    
    
    #Free cache.
    tables.clear if tables
    tables = nil
  end
  
  private
  
  ROWS_INIT_ALLOWED_ARGS = [:db, :table, :rows]
  #This method checks if certain rows are present in a table based on a hash.
  def rows_init(args)
    args.each do |key, val|
      raise "Invalid key: '#{key}' (#{key.class.name})." unless ROWS_INIT_ALLOWED_ARGS.include?(key)
    end
    
    db = args[:db]
    table = args[:table]
    
    raise "No db given." if !db
    raise "No table given." if !table
    
    args[:rows].each do |row_data|
      if row_data[:find_by]
        find_by = row_data[:find_by]
      elsif row_data[:data]
        find_by = row_data[:data]
      else
        raise "Could not figure out the find-by."
      end
      
      rows_found = 0
      args[:db].select(table.name, find_by) do |d_rows|
        rows_found += 1
        
        if Knj::ArrayExt.hash_diff?(Knj::ArrayExt.hash_sym(row_data[:data]), Knj::ArrayExt.hash_sym(d_rows), {"h2_to_h1" => false})
          print "Data was not right - updating row: #{JSON.generate(row_data[:data])}\n" if args[:debug]
          args[:db].update(table.name, row_data[:data], d_rows)
        end
      end
      
      if rows_found == 0
        print "Inserting row: #{JSON.generate(row_data[:data])}\n" if args[:debug]
        table.insert(row_data[:data])
      end
    end
  end
end