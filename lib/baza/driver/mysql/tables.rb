require "monitor"

# This class handels various MySQL-table-specific behaviour.
class Baza::Driver::Mysql::Tables < Baza::Tables
  attr_reader :db, :list

  # Constructor. This should not be called manually.
  def initialize(db:, **args)
    @args = args
    @db = db
    @list_mutex = Monitor.new
    @list = Wref::Map.new
    @list_should_be_reloaded = true
  end

  # Cleans the wref-map.
  def clean
    @list.clean
  end

  def exists?(table_name)
    table_name = table_name.to_s
    table = @list[table_name]

    return true if table

    list(name: table_name) do
      return true
    end

    false
  end

  # Returns a table by the given table-name.
  def [](table_name)
    table_name = table_name.to_s
    table = @list[table_name]

    return table if table

    list(name: table_name) do |table_i|
      return table_i if table_i.name == table_name
    end

    raise Baza::Errors::TableNotFound, "Table was not found: '#{table_name}'"
  end

  # Yields the tables of the current database.
  def list(database: nil, name: nil)
    ret = [] unless block_given?

    where_args = {}
    where_args["TABLE_NAME"] = name if name

    if database
      where_args["TABLE_SCHEMA"] = database
    else
      where_args["TABLE_SCHEMA"] = @db.opts.fetch(:db)
    end

    @list_mutex.synchronize do
      @db.select([:information_schema, :tables], where_args) do |d_tables|
        name = d_tables.fetch(:TABLE_NAME)
        obj = @list.get(name)

        unless obj
          obj = Baza::Driver::Mysql::Table.new(
            db: @db,
            data: d_tables,
            tables: self
          )
          @list[name] = obj
        end

        if block_given?
          yield obj
        else
          ret << obj
        end
      end
    end

    if block_given?
      return nil
    else
      return ret
    end
  end

  def create(name, **opts)
    @db.current_database.create_table(name, **opts)
  end

private

  def add_to_list(table)
    raise "Already exists: '#{table.name}'." if @list.key?(table.name) && @list[table.name].__id__ != table.__id__
    @list[table.name] = table
  end

  def remove_from_list(table)
    raise "Table not in list: '#{table.name}'." unless @list.key?(table.name)
    @list.delete(table.name)
  end
end
