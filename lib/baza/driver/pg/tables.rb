class Baza::Driver::Pg::Tables < Baza::Tables
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

    tables_list
  end

  def create(table_name, data, args = nil)
    table_name = table_name.to_s
    raise "Invalid table name: #{table_name}" if table_name.strip.empty?
    raise "No columns was given for '#{table_name}'." if !data[:columns] || data[:columns].empty?

    create_table_sql = "CREATE"
    create_table_sql << " TEMPORARY" if data[:temp]
    create_table_sql << " TABLE #{db.quote_table(table_name)} ("

    first = true
    data.fetch(:columns).each do |col_data|
      create_table_sql << ", " unless first
      first = false if first
      col_data.delete(:after) if col_data[:after]
      create_table_sql << db.columns.data_sql(col_data)
    end

    create_table_sql << ")"

    sqls = [create_table_sql]

    if data[:indexes] && !data[:indexes].empty?
      sqls += db.indexes.create_index(data.fetch(:indexes), table_name: table_name, return_sql: true)
    end

    if !args || !args[:return_sql]
      db.transaction do
        sqls.each do |sql|
          db.query(sql)
        end
      end
    else
      sqls
    end
  end
end
