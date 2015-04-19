class Baza::Driver::Sqlite3::Tables
  attr_reader :db, :driver

  def initialize(args)
    @args = args
    @db = @args[:db]

    @list_mutex = Mutex.new
    @list = Wref::Map.new
  end

  def [](table_name)
    table_name = table_name.to_sym

    if ret = @list.get(table_name)
      return ret
    end

    self.list do |table_obj|
      return table_obj if table_obj.name == table_name
    end

    raise Errno::ENOENT, "Table was not found: #{table_name}."
  end

  def list
    ret = {} unless block_given?

    @list_mutex.synchronize do
      q_tables = @db.select("sqlite_master", {"type" => "table"}, {orderby: "name"}) do |d_tables|
        next if d_tables[:name] == "sqlite_sequence"

        tname = d_tables[:name].to_sym
        obj = @list.get(tname)

        unless obj
          obj = Baza::Driver::Sqlite3::Table.new(
            db: @db,
            data: d_tables,
            tables: self
          )
          @list[tname] = obj
        end

        if block_given?
          yield(obj)
        else
          ret[tname] = obj
        end
      end
    end

    if block_given?
      return nil
    else
      return ret
    end
  end

  def exists_in_list? table
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
    data.each do |key, val|
      raise "Invalid key: '#{key}' (#{key.class.name})." unless CREATE_ALLOWED_KEYS.include?(key)
    end

    sql = "CREATE TABLE `#{name}` ("

    first = true
    data[:columns].each do |col_data|
      sql << ", " if !first
      first = false if first
      sql << @db.cols.data_sql(col_data)
    end

    sql << ")"

    if args && args[:return_sql]
      ret = [sql]
    else
      @db.query(sql)
    end

    if data.key?(:indexes) && data[:indexes]
      table_obj = self[name]

      if args && args[:return_sql]
        ret += table_obj.create_indexes(data[:indexes], return_sql: true)
      else
        table_obj.create_indexes(data[:indexes])
      end
    end

    if args && args[:return_sql]
      return ret
    else
      return nil
    end
  end
end
