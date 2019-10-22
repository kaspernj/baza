class Baza::Driver::Pg::Table < Baza::Table
  attr_reader :name

  def initialize(driver:, data:)
    @db = driver.db
    @data = data
    @name = @data.fetch(:table_name)
  end

  def drop
    @db.with_database(database_name) do
      @db.query("DROP TABLE #{@db.quote_table(name)}")
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
      ret[:indexes] << index.data
    end

    ret
  end

  def database_name
    @data.fetch(:table_catalog)
  end

  def native?
    name == "pg_stat_statements"
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
    raise Baza::Errors::ColumnNotFound, "Column not found: #{name}" unless column
    column
  end

  def truncate
    @db.query("TRUNCATE #{@db.quote_table(name)} RESTART IDENTITY")
    self
  end

  def foreign_keys(args = {})
    sql = "
      SELECT
        tc.constraint_name,
        tc.table_name,
        kcu.column_name,
        ccu.table_name AS foreign_table_name,
        ccu.column_name AS foreign_column_name

      FROM
        information_schema.table_constraints AS tc

      JOIN information_schema.key_column_usage AS kcu ON
        tc.constraint_name = kcu.constraint_name

      JOIN information_schema.constraint_column_usage AS ccu
        ON ccu.constraint_name = tc.constraint_name

      WHERE
        constraint_type = 'FOREIGN KEY' AND
        tc.table_name = '#{@db.escape(name)}'
    "

    sql << " AND tc.constraint_name = '#{@db.escape(args.fetch(:name))}'" if args[:name]

    result = [] unless block_given?

    @db.query(sql) do |data|
      foreign_key = Baza::Driver::Pg::ForeignKey.new(
        db: @db,
        data: data
      )

      if block_given?
        yield foreign_key
      else
        result << foreign_key
      end
    end

    result
  end

  def foreign_key(name)
    foreign_keys(name: name) do |foreign_key|
      return foreign_key
    end

    raise Baza::Errors::ForeignKeyNotFound, "Foreign key not found: #{name}"
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

  def create_indexes(index_list, args = {})
    db.indexes.create_index(index_list, args.merge(table_name: name))
  end

  def rename(new_name)
    @db.query("ALTER TABLE #{@db.quote_table(name)} RENAME TO #{@db.quote_table(new_name)}")
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

  def rows_count
    @db.databases.with_database(database_name) do
      sql = "SELECT COUNT(*) AS count FROM #{@db.quote_table(name)}"
      return @db.query(sql).fetch.fetch(:count).to_i
    end
  end

  def optimize
    @db.query("VACUUM #{@db.quote_table(name)}")
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

    clone_insert_from_original_table(newname, columns_list)

    @db.tables[newname]
  end

private

  def clone_insert_from_original_table(newname, columns_list)
    sql_clone = "INSERT INTO #{@db.quote_table(newname)} ("

    first = true
    columns_list.each do |column_data|
      sql_clone << "," unless first
      first = false if first
      sql_clone << @db.quote_column(column_data.fetch(:name))
    end

    sql_clone << ") SELECT "

    first = true
    columns_list.each do |column_data|
      sql_clone << "," unless first
      first = false if first
      sql_clone << @db.quote_column(column_data.fetch(:name))
    end

    sql_clone << " FROM #{@db.quote_table(name)}"

    @db.query(sql_clone)
  end
end
