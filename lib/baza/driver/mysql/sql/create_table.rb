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
    sql << " TABLE #{Baza::Driver::Mysql::SEPARATOR_TABLE}#{Baza::Driver::Mysql.escape_table(@name)}#{Baza::Driver::Mysql::SEPARATOR_TABLE} ("

    first = true
    @columns.each do |col_data|
      sql << ", " unless first
      first = false if first
      col_data.delete(:after) if col_data[:after]

      sql << Baza::Driver::Mysql::Sql::Column.new(col_data).sql.first
    end

    if @indexes && !@indexes.empty?
      sql << ", "
      sql << Baza::Driver::Mysql::Sql::CreateIndexes.new(
        indexes: @indexes,
        create: false,
        on_table: false,
        table_name: @name
      ).sql.first
    end

    sql << ")"

    [sql]
  end
end
