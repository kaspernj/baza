class Baza::Driver::Sqlite3::Tables
  attr_reader :db, :driver

  def initialize(args)
    @args = args
    @db = @args[:db]

    @list_mutex = Mutex.new
    @list = Wref_map.new
  end

  def [](table_name)
    table_name = table_name.to_sym

    begin
      ret = @list[table_name]
      return ret
    rescue Wref::Recycled
      #ignore.
    end

    self.list do |table_obj|
      return table_obj if table_obj.name == table_name
    end

    raise Errno::ENOENT, "Table was not found: #{table_name}."
  end

  def list
    ret = {} unless block_given?

    @list_mutex.synchronize do
      q_tables = @db.select("sqlite_master", {"type" => "table"}, {:orderby => "name"}) do |d_tables|
        next if d_tables[:name] == "sqlite_sequence"

        tname = d_tables[:name].to_sym
        obj = @list.get!(tname)

        if !obj
          obj = Baza::Driver::Sqlite3::Tables::Table.new(
            :db => @db,
            :data => d_tables,
            :tables => self
          )
          @list[tname] = obj
        end

        if block_given?
          yield(obj)
        else
          ret[tname] = obj
        end
      end
    end

    if block_given?
      return nil
    else
      return ret
    end
  end

  def remove_from_list(table)
    @list.delete(table.name)
  end

  def add_to_list(table)
    raise "Already exists: '#{table.name}'." if @list.key?(table.name) and @list[table.name].__id__ != table.__id__
    @list[table.name] = table
  end

  CREATE_ALLOWED_KEYS = [:indexes, :columns]
  def create(name, data, args = nil)
    data.each do |key, val|
      raise "Invalid key: '#{key}' (#{key.class.name})." if !CREATE_ALLOWED_KEYS.include?(key)
    end

    sql = "CREATE TABLE `#{name}` ("

    first = true
    data[:columns].each do |col_data|
      sql << ", " if !first
      first = false if first
      sql << @db.cols.data_sql(col_data)
    end

    sql << ")"

    if args and args[:return_sql]
      ret = [sql]
    else
      @db.query(sql)
    end

    if data.key?(:indexes) and data[:indexes]
      table_obj = self[name]

      if args and args[:return_sql]
        ret += table_obj.create_indexes(data[:indexes], :return_sql => true)
      else
        table_obj.create_indexes(data[:indexes])
      end
    end

    if args and args[:return_sql]
      return ret
    else
      return nil
    end
  end
end

class Baza::Driver::Sqlite3::Tables::Table
  attr_reader :name, :type

  def initialize(args)
    @db = args[:db]
    @data = args[:data]
    @name = @data[:name].to_sym
    @type = @data[:type].to_sym
    @tables = args[:tables]

    @list = Wref_map.new
    @indexes_list = Wref_map.new
  end

  def maxlength
    return @data[:maxlength]
  end

  def reload
    @data = @db.select("sqlite_master", {"type" => "table", "name" => self.name}, {:orderby => "name"}).fetch
  end

  def rows_count
    data = @db.q("SELECT COUNT(*) AS count FROM `#{self.name}`").fetch
    return data[:count].to_i
  end

  #Drops the table from the database.
  def drop
    raise "Cant drop native table: '#{self.name}'." if self.native?
    @db.query("DROP TABLE `#{self.name}`")
    @tables.remove_from_list(self)
  end

  #Returns true if the table is safe to drop.
  def native?
    return true if self.name.to_s == "sqlite_sequence"
    return false
  end

  def optimize
    # Not possible in SQLite3.
  end

  def rename(newname)
    newname = newname.to_sym

    @tables.remove_from_list(self)
    self.clone(newname, :return_table => false)
    self.drop
    @data[:name] = newname
    @name = newname
    @tables.add_to_list(self)

    #Rename table on all columns.
    #FIXME: This should only be done for columns that exists in memory. However a reference to the table should not be set, at this would force the table to stay in memory, when the column is still referenced...
    self.columns.each do |name, col|
      col.args[:table_name] = newname
    end
  end

  def truncate
    @db.query("DELETE FROM `#{self.name}` WHERE 1=1")
    return nil
  end

  def table
    return @db.tables[@table_name]
  end

  def column(name)
    list = self.columns
    return list[name] if list[name]
    raise Errno::ENOENT.new("Column not found: #{name}.")
  end

  def columns
    @db.cols
    ret = {}

    @db.q("PRAGMA table_info(`#{@db.esc_table(self.name)}`)") do |d_cols|
      name = d_cols[:name].to_sym
      obj = @list.get!(name)

      if !obj
        obj = Baza::Driver::Sqlite3::Columns::Column.new(
          :table_name => self.name,
          :db => @db,
          :data => d_cols
        )
        @list[name] = obj
      end

      if block_given?
        yield(obj)
      else
        ret[name] = obj
      end
    end

    if block_given?
      return nil
    else
      return ret
    end
  end

  def create_columns(col_arr)
    col_arr.each do |col_data|
      #if col_data.key?("after")
      #  self.create_column_programmatic(col_data)
      #else
        @db.query("ALTER TABLE `#{self.name}` ADD COLUMN #{@db.cols.data_sql(col_data)};")
      #end
    end
  end

  def create_column_programmatic(col_data)
    temp_name = "temptable_#{Time.now.to_f.to_s.hash}"
    cloned_tabled = self.clone(temp_name)
    cols_cur = self.columns
    @db.query("DROP TABLE `#{self.name}`")

    sql = "CREATE TABLE `#{self.name}` ("
    first = true
    cols_cur.each do |name, col|
      sql << ", " if !first
      first = false if first
      sql << @db.cols.data_sql(col.data)

      if col_data[:after] and col_data[:after] == name
        sql << ", #{@db.cols.data_sql(col_data)}"
      end
    end
    sql << ");"
    @db.query(sql)

    sql = "INSERT INTO `#{self.name}` SELECT "
    first = true
    cols_cur.each do |name, col|
      sql << ", " if !first
      first = false if first

      sql << "`#{name}`"

      if col_data[:after] and col_data[:after] == name
        sql << ", ''"
      end
    end
    sql << " FROM `#{temp_name}`"
    @db.query(sql)
    @db.query("DROP TABLE `#{temp_name}`")
  end

  def clone(newname, args = nil)
    raise "Invalid name." if newname.to_s.strip.length <= 0
    cols_cur = self.columns

    sql = "CREATE TABLE `#{newname}` ("
    first = true
    cols_cur.each do |name, col|
      sql << ", " if !first
      first = false if first
      sql << @db.cols.data_sql(col.data)
    end

    sql << ");"
    @db.query(sql)

    sql = "INSERT INTO `#{newname}` SELECT * FROM `#{self.name}`"
    @db.query(sql)

    if args and args[:return_table] == false
      return nil
    else
      return @db.tables[newname]
    end
  end

  def copy(args = {})
    temp_name = "temptable_#{Time.now.to_f.to_s.hash}"
    cloned_tabled = self.clone(temp_name)
    cols_cur = self.columns
    @db.query("DROP TABLE `#{self.name}`")

    sql = "CREATE TABLE `#{self.name}` ("
    first = true
    cols_cur.each do |name, col|
      next if args[:drops] and args[:drops].index(name) != nil

      sql << ", " if !first
      first = false if first

      if args.key?(:alter_columns) and args[:alter_columns][name.to_sym]
        sql << @db.cols.data_sql(args[:alter_columns][name.to_sym])
      else
        sql << @db.cols.data_sql(col.data)
      end

      if args[:new]
        args[:new].each do |col_data|
          if col_data[:after] and col_data[:after] == name
            sql << ", #{@db.cols.data_sql(col_data)}"
          end
        end
      end
    end
    sql << ");"
    @db.query(sql)

    sql = "INSERT INTO `#{self.name}` SELECT "
    first = true
    cols_cur.each do |name, col|
      next if args[:drops] and args[:drops].index(name) != nil

      sql << ", " if !first
      first = false if first

      sql << "`#{name}`"

      if args[:news]
        args[:news].each do |col_data|
          if col_data[:after] and col_data[:after] == name
            sql << ", ''"
          end
        end
      end
    end

    sql << " FROM `#{temp_name}`"
    @db.query(sql)
    @db.query("DROP TABLE `#{temp_name}`")
  end

  def index(name)
    name = name.to_sym

    begin
      return @indexes_list[name]
    rescue Wref::Recycled
      if @db.opts[:index_append_table_name]
        tryname = "#{self.name}__#{name}"

        begin
          return @indexes_list[tryname]
        rescue Wref::Recycled
          #ignore.
        end
      else
        #ignore
      end
    end

    self.indexes do |index|
      return index if index.name.to_s == name
    end

    raise Errno::ENOENT.new("Index not found: #{name}.")
  end

  def indexes
    @db.indexes
    ret = {} unless block_given?

    @db.q("PRAGMA index_list(`#{@db.esc_table(self.name)}`)") do |d_indexes|
      next if d_indexes[:Key_name] == "PRIMARY"

      obj = @indexes_list.get!(d_indexes[:name])

      if !obj
        if @db.opts[:index_append_table_name]
          match_name = d_indexes[:name].match(/__(.+)$/)

          if match_name
            name = match_name[1].to_sym
          else
            name = d_indexes[:name].to_sym
          end
        else
          name = d_indexes[:name].to_sym
        end

        obj = Baza::Driver::Sqlite3::Indexes::Index.new(
          :table_name => self.name,
          :db => @db,
          :data => d_indexes
        )
        obj.columns << name
        @indexes_list[d_indexes[:name].to_sym] = obj
      end

      if block_given?
        yield(obj)
      else
        ret[d_indexes[:name].to_sym] = obj
      end
    end

    if block_given?
      return nil
    else
      return ret
    end
  end

  def create_indexes(index_arr, args = nil)
    if args and args[:return_sql]
      ret = []
    end

    index_arr.each do |index_data|
      if index_data.is_a?(String) or index_data.is_a?(Symbol)
        index_data = {:name => index_data, :columns => [index_data]}
      end

      raise "No name was given in data: '#{index_data}'." if !index_data.key?(:name) or index_data[:name].to_s.strip.empty?
      raise "No columns was given on index #{index_data[:name]}." if index_data[:columns].empty?

      name = index_data[:name]
      name = "#{self.name}__#{name}" if @db.opts[:index_append_table_name]

      sql = "CREATE"
      sql << " UNIQUE" if index_data[:unique]
      sql << " INDEX '#{@db.esc_col(name)}' ON `#{@db.esc_table(self.name)}` ("

      first = true
      index_data[:columns].each do |col_name|
        sql << ", " if !first
        first = false if first

        sql << "`#{@db.esc_col(col_name)}`"
      end

      sql << ")"

      if args and args[:return_sql]
        ret << sql
      else
        @db.query(sql)
      end
    end

    if args and args[:return_sql]
      return ret
    else
      return nil
    end
  end

  def data
    ret = {
      :name => name,
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
end