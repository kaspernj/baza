class Baza::Driver::Mysql::Table < Baza::Table
  attr_reader :list, :name

  def initialize(args)
    @args = args
    @db = args.fetch(:db)
    @data = args.fetch(:data)
    @list = Wref::Map.new
    @indexes_list = Wref::Map.new
    @name = @data.fetch(:Name)
    @tables = args.fetch(:tables)
  end

  def reload
    data = @db.q("SHOW TABLE STATUS WHERE `Name` = '#{@db.esc(name)}'").fetch
    raise Baza::Errors::TableNotFound unless data
    @data = data
    self
  end

  # Used to validate in Wref::Map.
  def __object_unique_id__
    name
  end

  def drop
    raise "Cant drop native table: '#{name}'." if self.native?
    @db.query("DROP TABLE `#{@db.esc_table(name)}`")
    @tables.__send__(:remove_from_list, self)
    nil
  end

  # Returns true if the table is safe to drop.
  def native?
    data = @db.q("SELECT DATABASE() AS db").fetch
    return true if data.fetch(:db) == "mysql"
    false
  end

  def optimize
    @db.query("OPTIMIZE TABLE `#{@db.esc_table(name)}`")
    self
  end

  def rows_count
    @db.q("SELECT COUNT(*) AS count FROM `#{@db.esc_table(name)}`").fetch.fetch(:count).to_i
  end

  def column(name)
    name = name.to_s

    if col = @list.get(name)
      return @list[name]
    end

    columns(name: name) do |col_i|
      return col_i if col_i.name == name
    end

    raise Baza::Errors::ColumnNotFound, "Column not found: '#{name}'"
  end

  def columns(args = nil)
    @db.cols
    ret = []
    sql = "SHOW FULL COLUMNS FROM `#{@db.esc_table(name)}`"
    sql << " WHERE `Field` = '#{@db.esc(args[:name])}'" if args && args.key?(:name)

    @db.q(sql) do |d_cols|
      column_name = d_cols.fetch(:Field)
      obj = @list.get(name)

      unless obj
        obj = Baza::Driver::Mysql::Column.new(
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

  def indexes(args = nil)
    @db.indexes
    ret = []

    sql = "SHOW INDEX FROM `#{@db.esc_table(name)}`"
    sql << " WHERE `Key_name` = '#{@db.esc(args[:name])}'" if args && args.key?(:name)

    @db.q(sql) do |d_indexes|
      next if d_indexes[:Key_name] == "PRIMARY"
      obj = @indexes_list.get(d_indexes[:Key_name])

      unless obj
        obj = Baza::Driver::Mysql::Index.new(
          table_name: name,
          db: @db,
          data: d_indexes
        )
        obj.columns << d_indexes[:Column_name]
        @indexes_list[d_indexes[:Key_name]] = obj
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

  def index(name)
    name = name.to_s

    if index = @indexes_list.get(name)
      return index
    end

    indexes(name: name) do |index_i|
      return index_i if index_i.name == name
    end

    raise Baza::Errors::IndexNotFound, "Index not found: #{name}."
  end

  def create_columns(col_arr)
    @db.transaction do
      col_arr.each do |col_data|
        sql = "ALTER TABLE `#{name}` ADD COLUMN #{@db.cols.data_sql(col_data)};"
        @db.query(sql)
      end
    end
  end

  def create_indexes(index_arr, args = {})
    Baza::Driver::Mysql::Table.create_indexes(index_arr, args.merge(table_name: name, db: @db))
  end

  def self.create_indexes(index_arr, args = {})
    db = args[:db]

    if args[:return_sql]
      sql = ""
      first = true
    end

    index_arr.each do |index_data|
      sql = "" unless args[:return_sql]

      sql << "CREATE" if args[:create] || !args.key?(:create)

      if index_data.is_a?(String) || index_data.is_a?(Symbol)
        index_data = {name: index_data, columns: [index_data]}
      end

      raise "No name was given: '#{index_data}'." if !index_data.key?(:name) || index_data[:name].to_s.strip.empty?
      raise "No columns was given on index: '#{index_data[:name]}'." if !index_data[:columns] || index_data[:columns].empty?

      if args[:return_sql]
        if first
          first = false
        else
          sql << ", "
        end
      end

      sql << " UNIQUE" if index_data[:unique]
      sql << " INDEX `#{db.esc_col(index_data[:name])}`"

      if args[:on_table] || !args.key?(:on_table)
        sql << " ON `#{db.esc_table(args[:table_name])}`"
      end

      sql << " ("

      first = true
      index_data[:columns].each do |col_name|
        sql << ", " unless first
        first = false if first

        sql << "`#{db.esc_col(col_name)}`"
      end

      sql << ")"

      db.query(sql) unless args[:return_sql]
    end

    if args[:return_sql]
      return sql
    else
      return nil
    end
  end

  def rename(newname)
    newname = newname.to_s
    oldname = name

    @tables.__send__(:remove_from_list, self)
    @db.query("ALTER TABLE `#{@db.esc_table(oldname)}` RENAME TO `#{@db.esc_table(newname)}`")

    @data[:Name] = newname
    @name = newname
    @tables.__send__(:add_to_list, self)

    @list.each do |_name, column|
      column.args[:table_name] = newname
    end

    @indexes_list.each do |_name, index|
      index.args[:table_name] = newname
    end
  end

  def truncate
    @db.query("TRUNCATE `#{@db.esc_table(name)}`")
    self
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

  def insert(data)
    @db.insert(name, data)
  end

  def clone(newname, args = {})
    raise "Invalid name." if newname.to_s.strip.empty?

    sql = "CREATE TABLE `#{@db.esc_table(newname)}` ("
    first = true
    pkey_found = false
    pkeys = []

    columns do |col|
      sql << ", " unless first
      first = false if first

      col_data = col.data
      pkey_found = true if !pkey_found && col_data[:primarykey] && args[:force_single_pkey]

      if args[:no_pkey] || (pkey_found && col_data[:primarykey] && args[:force_single_pkey])
        col_data[:primarykey] = false
      end

      if col_data[:primarykey]
        pkeys << col_data[:name]
        col_data.delete(:primarykey)
      end

      col_data[:storage] = args[:all_cols_storage] if args[:all_cols_storage]

      sql << @db.cols.data_sql(col_data)
    end

    unless pkeys.empty?
      sql << ", PRIMARY KEY ("

      first = true
      pkeys.each do |pkey|
        sql << ", " unless first
        first = false if first
        sql << "`#{@db.esc_col(pkey)}`"
      end

      sql << ")"
    end

    sql << ")"
    sql << " TABLESPACE #{args[:tablespace]}" if args[:tablespace]
    sql << " ENGINE=#{args[:engine]}" if args[:engine]
    sql << ";"

    # Create table.
    @db.query(sql)


    # Insert data of previous data in a single query.
    @db.query("INSERT INTO `#{@db.esc_table(newname)}` SELECT * FROM `#{@db.esc_table(name)}`")


    # Create indexes.
    new_table = @db.tables[newname]
    indexes_list = []
    indexes do |index|
      indexes_list << index.data unless index.primary?
    end

    new_table.create_indexes(indexes_list)


    # Return new table.
    new_table
  end

  # Returns the current engine of the table.
  def engine
    @data[:Engine]
  end

  # Changes the engine for a table.
  def engine=(newengine)
    raise "Invalid engine: '#{newengine}'." unless newengine.to_s.match(/^[A-z]+$/)
    @db.query("ALTER TABLE `#{@db.esc_table(name)}` ENGINE = #{newengine}") if engine.to_s != newengine.to_s
    @data[:Engine] = newengine
  end

private

  def remove_column_from_list(col)
    raise "Column not found: '#{col.name}'." unless @list.key?(col.name)
    @list.delete(col.name)
  end

  def add_column_to_list(col)
    raise "Column already exists: '#{col.name}'." if @list.key?(col.name)
    @list[col.name] = col
  end
end
