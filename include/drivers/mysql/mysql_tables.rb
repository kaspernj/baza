require "monitor"

#This class handels various MySQL-table-specific behaviour.
class Baza::Driver::Mysql::Tables
  attr_reader :db, :list
  
  #Constructor. This should not be called manually.
  def initialize(args)
    @args = args
    @db = @args[:db]
    @subtype = @db.opts[:subtype]
    @list_mutex = Monitor.new
    @list = Wref_map.new
    @list_should_be_reloaded = true
  end
  
  #Cleans the wref-map.
  def clean
    @list.clean
  end
  
  #Returns a table by the given table-name.
  def [](table_name)
    table_name = table_name.to_sym
    
    begin
      return @list[table_name]
    rescue Wref::Recycled
      #ignore.
    end
    
    self.list(:name => table_name) do |table_obj|
      return table_obj if table_obj.name == table_name
    end
    
    raise Errno::ENOENT, "Table was not found: #{table_name}."
  end
  
  #Yields the tables of the current database.
  def list(args = {})
    ret = {} unless block_given?
    
    sql = "SHOW TABLE STATUS"
    sql << " WHERE `Name` = '#{@db.esc(args[:name])}'" if args[:name]
    
    @list_mutex.synchronize do
      @db.q(sql) do |d_tables|
        name = d_tables[:Name].to_sym
        obj = @list.get!(name)
        
        if !obj
          obj = Baza::Driver::Mysql::Tables::Table.new(
            :db => @db,
            :data => d_tables
          )
          @list[name] = obj
        end
        
        if block_given?
          yield(obj)
        else
          ret[name] = obj
        end
      end
    end
    
    if block_given?
      return nil
    else
      return ret
    end
  end
  
  CREATE_ALLOWED_KEYS = [:columns, :indexes, :temp, :return_sql]
  #Creates a new table by the given name and data.
  def create(name, data, args = nil)
    raise "No columns was given for '#{name}'." if !data[:columns] or data[:columns].empty?
    
    sql = "CREATE"
    sql << " TEMPORARY" if data[:temp]
    sql << " TABLE `#{name}` ("
    
    first = true
    data[:columns].each do |col_data|
      sql << ", " if !first
      first = false if first
      col_data.delete(:after) if col_data[:after]
      sql << @db.cols.data_sql(col_data)
    end
    
    if data[:indexes] and !data[:indexes].empty?
      sql << ", "
      sql << Baza::Driver::Mysql::Tables::Table.create_indexes(data[:indexes], {
        :db => @db,
        :return_sql => true,
        :create => false,
        :on_table => false,
        :table_name => name
      })
    end
    
    sql << ")"
    
    return [sql] if args and args[:return_sql]
    @db.query(sql)
  end
end

class Baza::Driver::Mysql::Tables::Table
  attr_reader :list, :name
  
  def initialize(args)
    @args = args
    @db = args[:db]
    @data = args[:data]
    @subtype = @db.opts[:subtype]
    @list = Wref_map.new
    @indexes_list = Wref_map.new
    @name = @data[:Name].to_sym
    
    raise "Could not figure out name from: '#{@data}'." if @data[:Name].to_s.strip.length <= 0
  end
  
  def reload
    @data = @db.q("SHOW TABLE STATUS WHERE `Name` = '#{@db.esc(self.name)}'").fetch
  end
  
  #Used to validate in Knj::Wrap_map.
  def __object_unique_id__
    return @data[:Name]
  end
  
  def drop
    raise "Cant drop native table: '#{self.name}'." if self.native?
    @db.query("DROP TABLE `#{self.name}`")
  end
  
  #Returns true if the table is safe to drop.
  def native?
    return true if @db.q("SELECT DATABASE() AS db").fetch[:db] == "mysql"
    return false
  end
  
  def optimize
    @db.query("OPTIMIZE TABLE `#{self.name}`")
    return self
  end
  
  def rows_count
    return @data[:Rows].to_i
  end
  
  def column(name)
    name = name.to_sym
    
    if col = @list.get!(name)
      return @list[name]
    end
    
    self.columns(:name => name) do |col|
      return col if col.name == name
    end
    
    raise Errno::ENOENT, "Column not found: '#{name}'."
  end
  
  def columns(args = nil)
    @db.cols
    ret = {}
    sql = "SHOW FULL COLUMNS FROM `#{self.name}`"
    sql << " WHERE `Field` = '#{@db.esc(args[:name])}'" if args and args.key?(:name)
    
    @db.q(sql) do |d_cols|
      obj = @list.get!(d_cols[:Field].to_s)
      
      if !obj
        obj = Baza::Driver::Mysql::Columns::Column.new(
          :table_name => self.name,
          :db => @db,
          :data => d_cols
        )
        @list[d_cols[:Field].to_s] = obj
      end
      
      if block_given?
        yield(obj)
      else
        ret[d_cols[:Field].to_s] = obj
      end
    end
    
    if block_given?
      return nil
    else
      return ret
    end
  end
  
  def indexes(args = nil)
    @db.indexes
    ret = {}
    
    sql = "SHOW INDEX FROM `#{self.name}`"
    sql << " WHERE `Key_name` = '#{@db.esc(args[:name])}'" if args and args.key?(:name)
    
    @db.q(sql) do |d_indexes|
      next if d_indexes[:Key_name] == "PRIMARY"
      
      obj = @indexes_list.get!(d_indexes[:Key_name].to_s)
      
      if !obj
        obj = Baza::Driver::Mysql::Indexes::Index.new(
          :table_name => self.name,
          :db => @db,
          :data => d_indexes
        )
        obj.columns << d_indexes[:Column_name]
        @indexes_list[d_indexes[:Key_name].to_s] = obj
      end
      
      if block_given?
        yield(obj)
      else
        ret[d_indexes[:Key_name].to_s] = obj
      end
    end
    
    if block_given?
      return nil
    else
      return ret
    end
  end
  
  def index(name)
    name = name.to_s
    
    if index = @indexes_list.get!(name)
      return index
    end
    
    self.indexes(:name => name) do |index|
      return index if index.name.to_s == name
    end
    
    raise Errno::ENOENT, "Index not found: #{name}."
  end
  
  def create_columns(col_arr)
    col_arr.each do |col_data|
      sql = "ALTER TABLE `#{self.name}` ADD COLUMN #{@db.cols.data_sql(col_data)};"
      @db.query(sql)
    end
  end
  
  def create_indexes(index_arr, args = {})
    return Baza::Driver::Mysql::Tables::Table.create_indexes(index_arr, args.merge(:table_name => self.name, :db => @db))
  end
  
  def self.create_indexes(index_arr, args = {})
    db = args[:db]
    
    if args[:return_sql]
      sql = ""
      first = true
    end
    
    index_arr.each do |index_data|
      if !args[:return_sql]
        sql = ""
      end
      
      if args[:create] or !args.key?(:create)
        sql << "CREATE"
      end
      
      if index_data.is_a?(String)
        index_data = {:name => index_data, :columns => [index_data]}
      end
      
      raise "No name was given." if !index_data.key?(:name) or index_data[:name].strip.empty?
      raise "No columns was given on index: '#{index_data[:name]}'." if !index_data[:columns] or index_data[:columns].empty?
      
      if args[:return_sql]
        if first
          first = false
        else
          sql << ", "
        end
      end
      
      sql << " UNIQUE" if index_data[:unique]
      sql << " INDEX `#{db.esc_col(index_data[name])}`"
      
      if args[:on_table] or !args.key?(:on_table)
        sql << " ON `#{db.esc_table(args[:table_name])}`"
      end
      
      sql << " ("
      
      first = true
      index_data[:columns].each do |col_name|
        sql << ", " if !first
        first = false if first
        
        sql << "`#{db.esc_col(col_name)}`"
      end
      
      sql << ")"
      
      if !args[:return_sql]
        db.query(sql)
      end
    end
    
    if args[:return_sql]
      return sql
    else
      return nil
    end
  end
  
  def rename(newname)
    oldname = self.name
    @db.query("ALTER TABLE `#{oldname}` RENAME TO `#{newname}`")
    @db.tables.list[newname] = self
    @db.tables.list.delete(oldname)
    @data[:Name] = newname
  end
  
  def truncate
    @db.query("TRUNCATE `#{self.name}`")
    return self
  end
  
  def data
    ret = {
      :name => self.name,
      :columns => [],
      :indexes => []
    }
    
    columns.each do |name, column|
      ret[:columns] << column.data
    end
    
    indexes.each do |name, index|
      ret[:indexes] << index.data if name != "PRIMARY"
    end
    
    return ret
  end
  
  def insert(data)
    @db.insert(self.name, data)
  end
  
  #Returns the current engine of the table.
  def engine
		return @data[:Engine]
  end
  
  def clone(newname, args = {})
    raise "Invalid name." if newname.to_s.strip.empty?
    
    sql = "CREATE TABLE `#{@db.esc_table(newname)}` ("
    first = true
    pkey_found = false
    pkeys = []
    
    self.columns do |col|
      sql << ", " if !first
      first = false if first
      
      col_data = col.data
      pkey_found = true if !pkey_found and col_data[:primarykey] and args[:force_single_pkey]
      
      if args[:no_pkey] or (pkey_found and col_data[:primarykey] and args[:force_single_pkey])
				col_data[:primarykey] = false
			end
			
			if col_data[:primarykey]
				pkeys << col_data[:name]
				col_data.delete(:primarykey)
			end
			
			if args[:all_cols_storage]
				col_data[:storage] = args[:all_cols_storage]
			end
			
      sql << @db.cols.data_sql(col_data)
    end
    
    if !pkeys.empty?
			sql << ", PRIMARY KEY ("
			
			first = true
			pkeys.each do |pkey|
				sql << ", " if !first
				first = false if first
				sql << "`#{@db.esc_col(pkey)}`"
			end
			
			sql << ")"
    end
    
    sql << ")"
    sql << " TABLESPACE #{args[:tablespace]}" if args[:tablespace]
    sql << " ENGINE=#{args[:engine]}" if args[:engine]
    sql << ";"
    
    puts sql
    
    #Create table.
    @db.query(sql)
    
    
    #Insert data of previous data in a single query.
    @db.query("INSERT INTO `#{newname}` SELECT * FROM `#{self.name}`")
    
    
    #Create indexes.
    new_table = @db.tables[newname]
    indexes_list = []
    self.indexes do |index|
			indexes_list << index.data if !index.primary?
    end
    
    new_table.create_indexes(indexes_list)
    
    
    #Return new table.
    return new_table
  end
  
  #Changes the engine for a table.
  def engine=(newengine)
		raise "Invalid engine: '#{newengine}'." if !newengine.to_s.match(/^[A-z]+$/)
		@db.query("ALTER TABLE `#{@db.esc_table(self.name)}` ENGINE = #{newengine}") if self.engine.to_s != newengine.to_s
		@data[:Engine] = newengine
  end
end