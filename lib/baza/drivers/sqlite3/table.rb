class Baza::Driver::Sqlite3::Table < Baza::Table
  attr_reader :name, :type

  def initialize(args)
    @db = args[:db]
    @data = args[:data]
    @name = @data[:name].to_sym
    @type = @data[:type].to_sym
    @tables = args[:tables]

    @list = Wref::Map.new
    @indexes_list = Wref::Map.new
  end

  def maxlength
    return @data[:maxlength]
  end

  def reload
    @data = @db.select("sqlite_master", {type: "table", name: name}, {orderby: "name"}).fetch
  end

  def rows_count
    data = @db.q("SELECT COUNT(*) AS count FROM `#{name}`").fetch
    return data[:count].to_i
  end

  #Drops the table from the database.
  def drop
    raise "Cant drop native table: '#{name}'." if native?
    @db.query("DROP TABLE `#{name}`")
    @tables.remove_from_list(self) if @tables.exists_in_list?(self)
  end

  #Returns true if the table is safe to drop.
  def native?
    return true if name.to_s == "sqlite_sequence"
    return false
  end

  def optimize
    # Not possible in SQLite3.
  end

  def rename(newname)
    newname = newname.to_sym

    @tables.remove_from_list(self)
    newtable = clone(newname)
    @db.tables.remove_from_list(newtable)
    drop
    @data[:name] = newname
    @name = newname
    @tables.add_to_list(self)

    #Rename table on all columns and indexes.
    @list.each do |name, column|
      column.args[:table_name] = newname
    end

    @indexes_list.each do |name, index|
      index.args[:table_name] = newname
    end
  end

  def truncate
    @db.query("DELETE FROM `#{name}` WHERE 1=1")
    return nil
  end

  def table
    return @db.tables[@table_name]
  end

  def column(name)
    list = self.columns
    return list[name] if list[name]
    raise Errno::ENOENT, "Column not found: #{name}."
  end

  def columns
    @db.cols
    ret = {}

    @db.q("PRAGMA table_info(`#{@db.esc_table(name)}`)") do |d_cols|
      column_name = d_cols[:name].to_sym
      obj = @list.get(column_name)

      unless obj
        obj = Baza::Driver::Sqlite3::Column.new(
          table_name: name,
          db: @db,
          data: d_cols
        )
        @list[column_name] = obj
      end

      if block_given?
        yield obj
      else
        ret[column_name] = obj
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
    raise "Invalid name." if newname.to_s.strip.empty?

    sql = "CREATE TABLE `#{newname}` ("
    first = true
    columns.each do |name, col|
      sql << ", " unless first
      first = false if first
      sql << @db.cols.data_sql(col.data)
    end

    sql << ");"
    @db.query(sql)
    @db.query("INSERT INTO `#{newname}` SELECT * FROM `#{name}`")

    indexes_to_create = []
    new_table = @db.tables[newname.to_sym]
    indexes.each do |name, index|
      index_name = name.to_s

      if @db.opts[:index_append_table_name] && match = index_name.match(/\A(.+?)__(.+)\Z/)
        index_name = match[2]
      end

      create_data = index.data
      create_data[:name] = index_name

      indexes_to_create << create_data
    end

    new_table.create_indexes(indexes_to_create)

    if args && args[:return_table] == false
      return nil
    else
      return new_table
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
      next if args[:drops] && args[:drops].to_s.include?(name.to_s)

      sql << ", " if !first
      first = false if first

      if args.key?(:alter_columns) && args[:alter_columns][name.to_sym]
        sql << @db.cols.data_sql(args[:alter_columns][name.to_sym])
      else
        sql << @db.cols.data_sql(col.data)
      end

      if args[:new]
        args[:new].each do |col_data|
          if col_data[:after] && col_data[:after] == name
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
      next if args[:drops] && args[:drops].to_s.include?(name.to_s)

      sql << ", " if !first
      first = false if first

      sql << "`#{name}`"

      if args[:news]
        args[:news].each do |col_data|
          if col_data[:after] && col_data[:after] == name.to_s
            sql << ", ''"
          end
        end
      end
    end

    sql << " FROM `#{temp_name}`"
    @db.query(sql)
    @db.query("DROP TABLE `#{temp_name}`")
  end

  def index(index_name)
    index_name = index_name.to_sym

    if index = @indexes_list[index_name]
      return index
    end

    if @db.opts[:index_append_table_name]
      tryname = "#{name}__#{index_name}"

      if index = @indexes_list[tryname]
        return index
      end
    end

    indexes do |index|
      if index.name.to_s == "#{name}__#{index_name}"
        return index
      end

      return index if index.name.to_s == index_name.to_s
    end

    raise Errno::ENOENT, "Index not found: #{index_name}."
  end

  def indexes
    @db.indexes
    ret = {} unless block_given?

    @db.q("PRAGMA index_list(`#{@db.esc_table(name)}`)") do |d_indexes|
      next if d_indexes[:Key_name] == "PRIMARY"
      obj = @indexes_list.get(d_indexes[:name])

      unless obj
        obj = Baza::Driver::Sqlite3::Index.new(
          table_name: name,
          db: @db,
          data: d_indexes
        )

        @indexes_list[d_indexes[:name].to_sym] = obj

        # Get columns from index.
        index_master_data = @db.single(:sqlite_master, type: "index", name: d_indexes[:name])
        parse_columns_from_sql(index_master_data[:sql]).each do |column|
          obj.columns << column
        end
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
    if args && args[:return_sql]
      ret = []
    end

    index_arr.each do |index_data|
      if index_data.is_a?(String) or index_data.is_a?(Symbol)
        index_data = {name: index_data, columns: [index_data]}
      end

      raise "No name was given in data: '#{index_data}'." if !index_data.key?(:name) || index_data[:name].to_s.strip.empty?
      raise "No columns was given on index #{index_data[:name]}." if !index_data[:columns] || index_data[:columns].empty?

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

      if args && args[:return_sql]
        ret << sql
      else
        @db.query(sql)
      end
    end

    if args && args[:return_sql]
      return ret
    else
      return nil
    end
  end

  def data
    ret = {
      name: name,
      columns: [],
      indexes: []
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
    @db.insert(name, data)
  end

  def to_s
    "#<Baza::Driver::Sqlite3::Table name: \"#{name}\">"
  end

  def inspect
    to_s
  end

private

  def parse_columns_from_sql sql
    columns_sql = sql.match(/\((.+?)\)\Z/)[1]
    return columns_sql.split(",").map{ |column| column[1, column.length - 2] }
  end
end