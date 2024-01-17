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
    sql << " TABLE #{Baza::Driver::Mysql.quote_table(@name)} ("

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

    @columns.each do |col_data|
      next unless col_data.key?(:foreign_key)

      sql << ","
      sql << " CONSTRAINT `#{col_data.fetch(:foreign_key).fetch(:name)}`" if col_data.fetch(:foreign_key)[:name]
      sql << " FOREIGN KEY (`#{col_data.fetch(:name)}`) REFERENCES `#{col_data.fetch(:foreign_key).fetch(:to).fetch(0)}` (`#{col_data.fetch(:foreign_key).fetch(:to).fetch(1)}`)"
    end

    sql << ")"

    [sql]
  end
end
