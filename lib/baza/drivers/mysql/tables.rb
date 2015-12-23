require "monitor"

# This class handels various MySQL-table-specific behaviour.
class Baza::Driver::Mysql::Tables
  attr_reader :db, :list

  # Constructor. This should not be called manually.
  def initialize(args)
    @args = args
    @db = @args[:db]
    @list_mutex = Monitor.new
    @list = Wref::Map.new
    @list_should_be_reloaded = true
  end

  # Cleans the wref-map.
  def clean
    @list.clean
  end

  # Returns a table by the given table-name.
  def [](table_name)
    table_name = table_name.to_s

    if table = @list[table_name]
      return table
    end

    list(name: table_name) do |table|
      return table if table.name == table_name
    end

    raise Baza::Errors::TableNotFound, "Table was not found: '#{table_name}'"
  end

  # Yields the tables of the current database.
  def list(args = {})
    ret = [] unless block_given?

    sql = "SHOW TABLE STATUS"
    sql << " WHERE `Name` = '#{@db.esc(args[:name])}'" if args[:name]

    @list_mutex.synchronize do
      @db.q(sql) do |d_tables|
        raise "No name was given from: #{d_tables}" unless d_tables.is_a?(Hash) && d_tables[:Name]
        name = d_tables[:Name]
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

  CREATE_ALLOWED_KEYS = [:columns, :indexes, :temp, :return_sql]
  # Creates a new table by the given name and data.
  def create(name, data, args = nil)
    raise "No columns was given for '#{name}'." if !data[:columns] || data[:columns].empty?

    sql = "CREATE"
    sql << " TEMPORARY" if data[:temp]
    sql << " TABLE `#{name}` ("

    first = true
    data[:columns].each do |col_data|
      sql << ", " unless first
      first = false if first
      col_data.delete(:after) if col_data[:after]
      sql << @db.cols.data_sql(col_data)
    end

    if data[:indexes] && !data[:indexes].empty?
      sql << ", "
      sql << Baza::Driver::Mysql::Table.create_indexes(data[:indexes],         db: @db,
                                                                               return_sql: true,
                                                                               create: false,
                                                                               on_table: false,
                                                                               table_name: name)
    end

    sql << ")"

    return [sql] if args && args[:return_sql]
    @db.query(sql)
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
