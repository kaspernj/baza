class Baza::Driver::Mysql::Sql::CreateTable
  def initialize(args)
    @name = args.fetch(:name)
    @columns = args.fetch(:columns)
    @indexes = args[:indexes]
    @temporary = args[:temporary]
  end

  def sql
    sql = "CREATE"
    sql << " TEMPORARY" if @temporary
    sql << " TABLE #{db.sep_table}#{@db.escape_table(@name)}#{db.sep_table} ("

    first = true
    @columns.each do |col_data|
      sql << ", " unless first
      first = false if first
      col_data.delete(:after) if col_data[:after]
      sql << @db.columns.data_sql(col_data)
    end

    if @indexes && !@indexes.empty?
      sql << ", "
      sql << Baza::Driver::Mysql::Table.create_indexes(
        @indexes,
        db: @db,
        return_sql: true,
        create: false,
        on_table: false,
        table_name: name
      )
    end

    sql << ")"

    [sql]
  end
end
