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

  def create(table_name, columns:, indexes: nil, return_sql: false, temp: false)
    table_name = table_name.to_s
    raise "Invalid table name: #{table_name}" if table_name.strip.empty?
    raise "No columns was given for '#{table_name}'." if !columns || columns.empty?

    create_table_sql = "CREATE"
    create_table_sql << " TEMPORARY" if temp
    create_table_sql << " TABLE #{db.quote_table(table_name)} ("

    first = true
    columns.each do |col_data|
      create_table_sql << ", " unless first
      first = false if first
      col_data.delete(:after) if col_data[:after]
      create_table_sql << db.columns.data_sql(col_data)
    end

    columns.each do |col_data| # rubocop :disable Style/CombinableLoops
      next unless col_data.key?(:foreign_key)

      create_table_sql << ","
      create_table_sql << " CONSTRAINT #{col_data.fetch(:foreign_key).fetch(:name)}" if col_data.fetch(:foreign_key)[:name]
      create_table_sql << " FOREIGN KEY (#{col_data.fetch(:name)}) " \
        "REFERENCES #{col_data.fetch(:foreign_key).fetch(:to).fetch(0)} (#{col_data.fetch(:foreign_key).fetch(:to).fetch(1)})"
    end

    create_table_sql << ")"

    sqls = [create_table_sql]

    if indexes && !indexes.empty?
      sqls += db.indexes.create_index(indexes, table_name: table_name, return_sql: true)
    end

    return sqls if return_sql

    db.transaction do
      sqls.each do |sql|
        db.query(sql)
      end
    end
  end
end
