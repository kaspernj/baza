# This class can be used to make SQL-dumps of databases, tables or however you want it.
class Baza::Dump
  # Constructor.
  #===Examples
  # dump = Baza::Dump.new(:db => db)
  def initialize(args)
    @db = args.fetch(:db)
    @db_type = args[:db_type]
    @debug = args[:debug]
    @tables = args[:tables]

    if @db_type
      @export_db = Baza::Db.new(type: @db_type)
    else
      @export_db = @db
    end
  end

  # Method used to update the status.
  def update_status
    return nil unless @on_status
    rows_count = Knj::Locales.number_out(@rows_count, 0)
    rows_count_total = Knj::Locales.number_out(@rows_count_total, 0)
    percent = (@rows_count.to_f / @rows_count_total.to_f) * 100
    percent_text = Knj::Locales.number_out(percent, 1)
    @on_status.call(text: "Dumping table: '#{@table_obj.name}' (#{rows_count}/#{rows_count_total} - #{percent_text}%).")
  end

  # Dumps all tables into the given IO.
  def dump(io)
    debug "Going through tables."
    @rows_count = 0

    if @tables
      tables = @tables
    else
      tables = @db.tables.list
    end

    if @on_status
      @on_status.call(text: "Preparing.")

      @rows_count_total = 0
      tables.each do |table_obj|
        @rows_count_total += table_obj.rows_count
      end
    end

    tables.each do |table_obj|
      table_obj = @db.tables[table_obj] if table_obj.is_a?(String) || table_obj.is_a?(Symbol)
      next if table_obj.native?

      # Figure out keys.
      @keys = []
      table_obj.columns do |col|
        @keys << col.name
      end

      @table_obj = table_obj
      update_status
      debug "Dumping table: '#{table_obj.name}'."
      dump_table(io, table_obj)
    end
  end

  # A block can be executed when a new status occurs.
  def on_status(&block)
    @on_status = block
  end

  def debug(message)
    puts message if @debug
  end

  # Dumps the given table into the given IO.
  def dump_table(io, table_obj)
    create_data = table_obj.data
    create_data.delete(:name)

    # Get SQL for creating table and add it to IO.
    sqls = @export_db.tables.create(table_obj.name, create_data, return_sql: true)
    sqls.each do |sql|
      io.write("#{sql};\n")
    end


    # Try to find a primary column in the table.
    prim_col = nil
    table_obj.columns do |col|
      if col.primarykey?
        prim_col = col
        break
      end
    end


    debug "Dumping data for table: #{table_obj.name}"

    # Set up rows and way to fill rows.
    rows = []


    @db.select(table_obj.name, nil, unbuffered: true) do |row|
      rows << row
      @rows_count += 1

      if rows.length >= 1000
        update_status
        dump_insert_multi(io, table_obj, rows)
      end
    end


    # Dump the last rows if any.
    dump_insert_multi(io, table_obj, rows) unless rows.empty?
  end

  # Dumps the given rows from the given table into the given IO.
  def dump_insert_multi(io, table_obj, rows)
    debug "Inserting #{rows.length} into #{table_obj.name}."
    sqls = @export_db.insert_multi(
      table_obj.name,
      rows,
      replace_line_breaks: true,
      return_sql: true,
      keys: @keys
    )
    sqls.each do |sql|
      io.write("#{sql};\n")
    end

    rows.clear

    # Ensure garbage collection or we might start using A LOT of memory.
    GC.start
  end
end
