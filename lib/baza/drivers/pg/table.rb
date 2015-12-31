class Baza::Driver::Pg::Table < Baza::Table
  attr_reader :name

  def initialize(args)
    @db = args.fetch(:driver).db
    @data = args.fetch(:data)
    @name = @data.fetch(:table_name)
  end

  def drop
    @db.with_database(database_name) do
      @db.query("DROP TABLE \"#{@db.escape_table(name)}\"")
    end
  end

  def database_name
    @data.fetch(:table_catalog)
  end

  def native?
    false
  end

  def columns(args = {})
    where_args = {
      table_catalog: @db.opts[:db],
      table_name: name,
      table_schema: "public"
    }

    where_args[:column_name] = args.fetch(:name) if args[:name]

    columns_list = [] unless block_given?
    @db.select([:information_schema, :columns], where_args) do |column_data|
      column = Baza::Driver::Pg::Column.new(
        db: @db,
        data: column_data
      )

      if columns_list
        columns_list << column
      else
        yield column
      end
    end

    columns_list
  end

  def column(name)
    column = columns(name: name).first
    raise Baza::Errors::ColumnNotFound unless column
    column
  end

  def truncate
    @db.query("TRUNCATE #{@db.sep_table}#{@db.escape_table(name)}#{@db.sep_table} RESTART IDENTITY")
    self
  end

  def indexes(args = {})
    where_args = {
      tablename: name
    }

    where_args[:indexname] = args.fetch(:name) if args[:name]

    indexes_list = [] unless block_given?
    @db.select(:pg_indexes, where_args) do |index_data|
      index = Baza::Driver::Pg::Index.new(
        db: @db,
        data: index_data
      )

      next if index.primary?

      if indexes_list
        indexes_list << index
      else
        yield index
      end
    end

    indexes_list
  end

  def index(name)
    index = indexes(name: name).first
    raise Baza::Errors::IndexNotFound unless index
    index
  end

  def create_indexes(index_arr, args = {})
    Baza::Driver::Pg::Table.create_indexes(index_arr, args.merge(table_name: name, db: @db))
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

      if !index_data.key?(:name) || index_data[:name].to_s.strip.empty?
        index_data[:name] = "index_on_#{args[:table_name] || name}_#{index_data.fetch(:columns).join("_")}"
      end

      raise "No columns was given on index: '#{index_data.fetch(:name)}'." if !index_data[:columns] || index_data[:columns].empty?

      if args[:return_sql]
        if first
          first = false
        else
          sql << ", "
        end
      end

      sql << " UNIQUE" if index_data[:unique]
      sql << " INDEX #{db.sep_index}#{db.escape_index(index_data.fetch(:name))}#{db.sep_index}"

      if args[:on_table] || !args.key?(:on_table)
        sql << " ON #{db.sep_table}#{db.escape_table(args.fetch(:table_name))}#{db.sep_table}"
      end

      sql << " ("

      first = true
      index_data[:columns].each do |col_name|
        sql << ", " unless first
        first = false if first

        sql << "#{db.sep_col}#{db.escape_column(col_name)}#{db.sep_col}"
      end

      sql << ")"

      db.query(sql) unless args[:return_sql]
    end

    sql if args[:return_sql]
  end

  def rename(new_name)
    @db.query("ALTER TABLE #{@db.sep_table}#{@db.escape_table(name)}#{@db.sep_table} RENAME TO #{@db.sep_table}#{@db.escape_table(new_name)}#{@db.sep_table}")
    @name = new_name.to_s
    self
  end

  def reload
    where_args = {
      table_catalog: @db.opts.fetch(:db),
      table_schema: "public",
      table_name: name
    }

    data = @db.single([:information_schema, :tables], where_args)
    raise Baza::Errors::TableNotFound unless data
    @data = data
    self
  end

  def optimize
    @db.query("VACUUM #{@db.sep_table}#{@db.escape_table(name)}#{@db.sep_table}")
    self
  end

  def clone(newname, _args = {})
    raise "Invalid name." if newname.to_s.strip.empty?

    columns_list = []
    indexes_list = []

    columns do |column|
      columns_list << column.data
    end

    indexes do |index|
      data = index.data
      data.delete(:name)
      indexes_list << data
    end

    @db.tables.create(newname, columns: columns_list, indexes: indexes_list)
    @db.query("INSERT INTO #{@db.sep_table}#{@db.escape_table(newname)}#{@db.sep_table} SELECT * FROM #{@db.sep_table}#{@db.escape_table(name)}#{@db.sep_table}")
    @db.tables[newname]
  end
end
