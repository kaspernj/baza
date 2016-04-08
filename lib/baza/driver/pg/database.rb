class Baza::Driver::Pg::Database < Baza::Database
  def save!
    rename(name) unless name.to_s == name_was
    self
  end

  def drop
    @db.query("DROP DATABASE #{@db.sep_database}#{@db.escape_database(name)}#{@db.sep_database}")
    self
  end

  def table(table_name)
    table = tables(name: table_name).first
    raise Baza::Errors::TableNotFound unless table
    table
  end

  def tables(args = {})
    tables_list = [] unless block_given?

    where_args = {
      table_catalog: name,
      table_schema: "public"
    }
    where_args[:table_name] = args.fetch(:name) if args[:name]

    use do
      @db.select([:information_schema, :tables], where_args, orderby: :table_name) do |table_data|
        table = Baza::Driver::Pg::Table.new(
          driver: @db.driver,
          data: table_data
        )

        next if table.native?

        if tables_list
          tables_list << table
        else
          yield table
        end
      end
    end

    tables_list
  end

  def use(&blk)
    @db.with_database(name, &blk)
    self
  end

  CREATE_ALLOWED_KEYS = [:columns, :indexes, :temp, :return_sql].freeze
  # Creates a new table by the given name and data.
  def create_table(table_name, data, args = nil)
    table_name = table_name.to_s
    raise "No columns was given for '#{name}'." if !data[:columns] || data[:columns].empty?

    sql = "CREATE"
    sql << " TEMPORARY" if data[:temp]
    sql << " TABLE #{db.sep_table}#{@db.escape_table(table_name)}#{db.sep_table} ("

    first = true
    data.fetch(:columns).each do |col_data|
      sql << ", " unless first
      first = false if first
      col_data.delete(:after) if col_data[:after]
      sql << @db.columns.data_sql(col_data)
    end

    sql << ")"

    use { @db.query(sql) } if !args || !args[:return_sql]

    if data[:indexes] && !data[:indexes].empty?
      table = @db.tables[table_name]
      table.create_indexes(data.fetch(:indexes))
    end

    return [sql] if args && args[:return_sql]
  end

private

  def rename(new_name)
    @db.query("ALTER DATABASE #{@db.sep_database}#{@db.escape_database(name_was)}#{@db.sep_database} RENAME TO #{@db.sep_database}#{@db.escape_database(new_name)}#{@db.sep_database}")
    @name = new_name.to_s
    self
  end
end
