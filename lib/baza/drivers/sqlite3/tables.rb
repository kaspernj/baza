require "monitor"

class Baza::Driver::Sqlite3::Tables
  attr_reader :db, :driver

  def initialize(args)
    @args = args
    @db = @args[:db]

    @list_mutex = Monitor.new
    @list = Wref::Map.new
  end

  def [](table_name)
    table_name = table_name.to_s

    if ret = @list.get(table_name)
      return ret
    end

    list(name: table_name) do |table|
      return table if table.name == table_name
    end

    raise Baza::Errors::TableNotFound, "Table was not found: #{table_name}."
  end

  def list(args = {})
    ret = [] unless block_given?

    @list_mutex.synchronize do
      tables_args = {type: "table"}
      tables_args[:name] = args.fetch(:name) if args[:name]

      q_tables = @db.select("sqlite_master", tables_args, orderby: "name") do |d_tables|
        table_name = d_tables.fetch(:name)
        next if table_name == "sqlite_sequence"

        obj = @list.get(table_name)

        unless obj
          obj = Baza::Driver::Sqlite3::Table.new(
            db: @db,
            data: d_tables,
            tables: self
          )
          @list[table_name] = obj
        end

        if block_given?
          yield obj
        else
          ret << obj
        end
      end
    end

    if block_given?
      nil
    else
      ret
    end
  end

  def exists_in_list?(table)
    @list.key?(table.name)
  end

  def remove_from_list(table)
    raise "Table doesnt exist: '#{table.name}'." unless @list.key?(table.name)
    @list.delete(table.name)
  end

  def add_to_list(table)
    raise "Already exists: '#{table.name}'." if @list.key?(table.name) && @list[table.name].__id__ != table.__id__
    @list[table.name] = table
  end

  CREATE_ALLOWED_KEYS = [:indexes, :columns]
  def create(name, data, args = nil)
    data.each_key do |key|
      raise "Invalid key: '#{key}' (#{key.class.name})." unless CREATE_ALLOWED_KEYS.include?(key)
    end

    raise "No columns given" if data.fetch(:columns).empty?

    sql = "CREATE TABLE `#{name}` ("

    first = true
    data.fetch(:columns).each do |col_data|
      sql << ", " unless first
      first = false if first
      sql << @db.cols.data_sql(col_data)
    end

    sql << ")"

    if args && args[:return_sql]
      ret = [sql]
    else
      @db.query(sql)
    end

    if data[:indexes]
      table_obj = self[name]

      if args && args[:return_sql]
        ret += table_obj.create_indexes(data.fetch(:indexes), return_sql: true)
      else
        table_obj.create_indexes(data.fetch(:indexes))
      end
    end

    if args && args[:return_sql]
      return ret
    else
      return nil
    end
  end
end
