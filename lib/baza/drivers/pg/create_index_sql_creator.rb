class Baza::Driver::Pg::CreateIndexSqlCreator
  def initialize(args)
    @db = args.fetch(:db)
    @indexes = args.fetch(:indexes)
    @create_args = args.fetch(:create_args)
  end

  def sqls
    sqls = []
    @indexes.each do |index_data|
      sqls << create_sql(index_data, @create_args)
    end

    sqls
  end

  def name_from_table_and_columns(table_name, column_names)
    "index_on_#{table_name}_#{column_names.join("_")}"
  end

  def create_sql(index_data, args)
    sql = ""
    sql << "CREATE" if args[:create] || !args.key?(:create)

    if index_data.is_a?(String) || index_data.is_a?(Symbol)
      index_data = {name: index_data, columns: [index_data]}
    elsif index_data[:name].to_s.strip.empty?
      index_data[:name] = name_from_table_and_columns(args[:table_name] || name, index_data.fetch(:columns))
    end

    raise "No columns was given on index: '#{index_data.fetch(:name)}'." if !index_data[:columns] || index_data[:columns].empty?

    sql << " UNIQUE" if index_data[:unique]
    sql << " INDEX #{@db.sep_index}#{@db.escape_index(index_data.fetch(:name))}#{@db.sep_index}"

    if args[:on_table] || !args.key?(:on_table)
      sql << " ON #{@db.sep_table}#{@db.escape_table(args.fetch(:table_name))}#{@db.sep_table}"
    end

    sql << " ("

    first = true
    index_data.fetch(:columns).each do |col_name|
      sql << ", " unless first
      first = false if first
      sql << "#{@db.sep_col}#{@db.escape_column(col_name)}#{@db.sep_col}"
    end

    sql << ")"
  end
end
