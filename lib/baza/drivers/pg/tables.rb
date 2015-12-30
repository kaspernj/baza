class Baza::Driver::Pg::Tables
  attr_reader :db

  def initialize(args)
    @args = args
    @db = @args.fetch(:db)
  end

  def [](table_name)
    table = list(name: table_name).first
    raise Baza::Errors::TableNotFound unless table
    table
  end

  def list(args = {})
    tables_list = [] unless block_given?

    where_args = {
      table_catalog: @db.opts[:db],
      table_schema: "public"
    }
    where_args[:table_name] = args.fetch(:name) if args[:name]

    @db.select([:information_schema, :tables], where_args, orderby: :table_name) do |table_data|
      table = Baza::Driver::Pg::Table.new(
        driver: self,
        data: table_data
      )

      next if table.native?

      if tables_list
        tables_list << table
      else
        yield table
      end
    end

    tables_list
  end

  CREATE_ALLOWED_KEYS = [:columns, :indexes, :temp, :return_sql]
  # Creates a new table by the given name and data.
  def create(name, data, args = nil)
    raise "No columns was given for '#{name}'." if !data[:columns] || data[:columns].empty?

    sql = "CREATE"
    sql << " TEMPORARY" if data[:temp]
    sql << " TABLE #{db.sep_table}#{@db.escape_table(name)}#{db.sep_table} ("

    first = true
    data.fetch(:columns).each do |col_data|
      sql << ", " unless first
      first = false if first
      col_data.delete(:after) if col_data[:after]
      sql << @db.cols.data_sql(col_data)
    end

    sql << ")"

    @db.query(sql) unless args && args[:return_sql]

    if data[:indexes] && !data[:indexes].empty?
      table = @db.tables[name]
      table.create_indexes(data.fetch(:indexes))
    end

    return [sql] if args && args[:return_sql]
  end
end
