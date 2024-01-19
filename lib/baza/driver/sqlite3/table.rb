class Baza::Driver::Sqlite3::Table < Baza::Table # rubocop:disable Metrics/ClassLength
  attr_reader :name, :type

  def initialize(args)
    @db = args.fetch(:db)
    @data = args.fetch(:data)
    @name = @data.fetch(:name)
    @type = @data.fetch(:type).to_sym
    @tables = args.fetch(:tables)

    @list = Wref::Map.new
    @indexes_list = Wref::Map.new
  end

  def foreign_keys
    db.query("PRAGMA foreign_key_list('#{name}')").map do |foreign_key_data|
      data = foreign_key_data.clone
      data[:referenced_table] = data.fetch(:table)
      data[:table] = name

      Baza::Driver::Sqlite3::ForeignKey.new(db: db, data: data)
    end
  end

  def referenced_foreign_keys
    sql = "
      SELECT
        sqlite_master.name,
        pragma_join.*

      FROM
        sqlite_master

      JOIN pragma_foreign_key_list(sqlite_master.name) pragma_join ON
        pragma_join.\"table\" != sqlite_master.name

      WHERE sqlite_master.type = 'table'
      ORDER BY sqlite_master.name
    "

    db.query(sql).map do |foreign_key_data|
      data = foreign_key_data.clone
      data[:referenced_table] = data.fetch(:table)
      data[:table] = data.fetch(:name)

      Baza::Driver::Sqlite3::ForeignKey.new(db: db, data: data)
    end
  end

  def maxlength
    @data.fetch(:maxlength)
  end

  def reload
    data = @db.select("sqlite_master", {type: "table", name: name}, orderby: "name").fetch
    raise Baza::Errors::TableNotFound unless data
    @data = data
    self
  end

  def rows_count
    data = @db.query("SELECT COUNT(*) AS count FROM `#{name}`").fetch
    data.fetch(:count).to_i
  end

  # Drops the table from the database.
  def drop
    raise "Cant drop native table: '#{name}'." if native?
    @db.query("DROP TABLE `#{name}`")
    @tables.remove_from_list(self) if @tables.exists_in_list?(self)
  end

  # Returns true if the table is safe to drop.
  def native?
    return true if name.to_s == "sqlite_sequence"
    false
  end

  def optimize
    # Not possible in SQLite3.
  end

  def rename(newname)
    newname = newname.to_s

    @tables.remove_from_list(self)
    newtable = clone(newname)
    @db.tables.remove_from_list(newtable)
    drop
    @data[:name] = newname
    @name = newname
    @tables.add_to_list(self)

    # Rename table on all columns and indexes.
    @list.each do |_name, column|
      column.args[:table_name] = newname
    end

    @indexes_list.each do |_name, index|
      index.args[:table_name] = newname
    end
  end

  # Drops the table and creates it again
  def truncate
    table_data = data.clone
    drop
    @db.tables.create(table_data.delete(:name), **table_data)
    self
  end

  def table
    @db.tables[@table_name]
  end

  def column(name)
    columns do |column|
      return column if column.name == name.to_s
    end

    raise Baza::Errors::ColumnNotFound, "Column not found: #{name}"
  end

  def columns
    @db.columns
    ret = []

    @db.query("PRAGMA table_info(#{@db.quote_table(name)})") do |d_cols|
      column_name = d_cols.fetch(:name)
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
        ret << obj
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
      # if col_data.key?("after")
      #  self.create_column_programmatic(col_data)
      # else
      @db.query("ALTER TABLE `#{name}` ADD COLUMN #{@db.columns.data_sql(col_data)};")
      # end
    end
  end

  def create_column_programmatic(col_data)
    temp_name = "temptable_#{Time.now.to_f.to_s.hash}"
    clone(temp_name)
    cols_cur = columns
    @db.query("DROP TABLE `#{name}`")

    sql = "CREATE TABLE `#{name}` ("
    first = true
    cols_cur.each do |name, col|
      sql << ", " unless first
      first = false if first
      sql << @db.columns.data_sql(col.data)

      if col_data[:after] && col_data[:after] == name
        sql << ", #{@db.columns.data_sql(col_data)}"
      end
    end
    sql << ");"
    @db.query(sql)

    sql = "INSERT INTO `#{self.name}` SELECT "
    first = true
    cols_cur.each do |name, _col|
      sql << ", " unless first
      first = false if first

      sql << "`#{name}`"

      sql << ", ''" if col_data[:after] && col_data[:after] == name
    end
    sql << " FROM `#{temp_name}`"
    @db.query(sql)
    @db.query("DROP TABLE `#{temp_name}`")
  end

  def clone(newname, args = nil)
    raise "Invalid name." if newname.to_s.strip.empty?

    sql = "CREATE TABLE `#{newname}` ("
    first = true
    columns.each do |col|
      sql << ", " unless first
      first = false if first
      sql << @db.columns.data_sql(col.data)
    end
    sql << ");"

    @db.query(sql)
    @db.query("INSERT INTO `#{newname}` SELECT * FROM `#{name}`")

    indexes_to_create = []
    new_table = @db.tables[newname.to_sym]
    indexes.each do |index|
      index_name = index.name.gsub(/\A#{Regexp.escape(name)}_/, "")

      if @db.opts[:index_append_table_name] && (match = index_name.match(/\A(.+?)__(.+)\Z/))
        index_name = match[2]
      else
        # Two indexes with the same name can't exist, and we are cloning, so we need to change the name
        index_name = "#{newname}_#{index_name}"
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
    clone(temp_name)
    cols_cur = columns
    @db.query("DROP TABLE `#{name}`")

    sql = "CREATE TABLE `#{name}` ("
    first = true
    cols_cur.each do |col|
      next if args[:drops] && args[:drops].to_s.include?(col.name)

      sql << ", " unless first
      first = false if first

      if args.key?(:alter_columns) && args[:alter_columns][col.name]
        sql << @db.columns.data_sql(args[:alter_columns][col.name])
      else
        sql << @db.columns.data_sql(col.data)
      end

      next unless args[:new]
      args[:new].each do |col_data|
        if col_data[:after] && col_data[:after] == col.name
          sql << ", #{@db.columns.data_sql(col_data)}"
        end
      end
    end

    sql << ");"
    @db.query(sql)

    sql = "INSERT INTO `#{name}` SELECT "
    first = true
    cols_cur.each do |col|
      next if args[:drops] && args[:drops].to_s.include?(col.name)

      sql << ", " unless first
      first = false if first

      sql << "`#{col.name}`"

      next unless args[:news]
      args[:news].each do |col_data|
        sql << ", ''" if col_data[:after] && col_data[:after] == col.name
      end
    end

    sql << " FROM `#{temp_name}`"
    @db.query(sql)
    @db.query("DROP TABLE `#{temp_name}`")
  end

  def index(index_name)
    index_name = index_name.to_s

    if (index = @indexes_list[index_name])
      return index
    end

    if @db.opts[:index_append_table_name]
      tryname = "#{name}__#{index_name}"

      if (index = @indexes_list[tryname])
        return index
      end
    end

    indexes do |index_i|
      return index_i if index_i.name == "#{name}__#{index_name}"
      return index_i if index_i.name == index_name
    end

    raise Baza::Errors::IndexNotFound, "Index not found: #{index_name}."
  end

  def indexes
    @db.indexes
    ret = [] unless block_given?

    @db.query("PRAGMA index_list(#{@db.quote_table(name)})") do |d_indexes|
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
        ret << obj
      end
    end

    if block_given?
      return nil
    else
      return ret
    end
  end

  def create_indexes(index_arr, args = nil)
    ret = [] if args && args[:return_sql]

    index_arr.each do |index_data|
      if index_data.is_a?(String) || index_data.is_a?(Symbol)
        index_data = {name: index_data, columns: [index_data]}
      end

      raise "No name was given in data: '#{index_data}'." if !index_data.key?(:name) || index_data[:name].to_s.strip.empty?
      raise "No columns was given on index #{index_data[:name]}." if !index_data[:columns] || index_data[:columns].empty?

      index_name = index_data.fetch(:name).to_s
      index_name = "#{name}__#{index_name}" if @db.opts[:index_append_table_name] && !index_name.start_with?("#{name}__")

      sql = "CREATE"
      sql << " UNIQUE" if index_data[:unique]
      sql << " INDEX #{@db.quote_index(index_name)} ON #{@db.quote_table(name)} ("

      first = true
      index_data.fetch(:columns).each do |col_name|
        sql << ", " unless first
        first = false if first
        sql << @db.quote_column(col_name)
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

    columns do |column|
      ret[:columns] << column.data
    end

    indexes do |index|
      ret[:indexes] << index.data unless index.name == "PRIMARY"
    end

    ret
  end

  def insert(data, args = {})
    @db.insert(name, data, args)
  end

  def to_s
    "#<Baza::Driver::Sqlite3::Table name: \"#{name}\">"
  end

  def inspect
    to_s
  end

private

  def parse_columns_from_sql(sql)
    columns_sql = sql.match(/\((.+?)\)\Z/)[1]

    columns_sql.split(",").map do |column|
      if (match = column.match(/`(.+)`/))
        match[1]
      elsif (match = column.match(/"(.+)"/))
        match[1]
      else
        raise "Couldn't parse column part: #{column}"
      end
    end
  end
end
