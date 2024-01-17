require "monitor"

class Baza::Driver::Sqlite3::Tables < Baza::Tables
  attr_reader :db, :driver

  def initialize(args)
    @args = args
    @db = @args[:db]

    @list_mutex = Monitor.new
    @list = Wref::Map.new
  end

  def [](table_name)
    table_name = table_name.to_s

    ret = @list.get(table_name)
    return ret if ret

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

      @db.select("sqlite_master", tables_args, orderby: "name") do |d_tables|
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

  def create(name, columns:, indexes: nil, return_sql: false)
    raise "No columns given" if !columns || columns.empty?

    sql = "CREATE TABLE `#{name}` ("

    first = true
    columns.each do |col_data|
      sql << ", " unless first
      first = false if first
      sql << @db.columns.data_sql(col_data)
    end

    columns.each do |col_data|
      next unless col_data.key?(:foreign_key)

      sql << ", FOREIGN KEY (#{col_data.fetch(:name)}) REFERENCES #{col_data.fetch(:foreign_key).fetch(:to).fetch(0)}(#{col_data.fetch(:foreign_key).fetch(:to).fetch(1)})"
    end

    sql << ")"

    if return_sql
      ret = [sql]
    else
      @db.query(sql)
    end

    if indexes
      table_obj = self[name]

      if return_sql
        ret += table_obj.create_indexes(indexes, return_sql: true)
      else
        table_obj.create_indexes(indexes)
      end
    end

    puts sql

    if return_sql
      return ret
    else
      return nil
    end
  end
end
