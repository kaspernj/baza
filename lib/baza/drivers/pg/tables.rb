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

  def create(name, data, args = nil)
    @db.current_database.create_table(name, data, args)
  end
end
