class Baza::SqlQueries::GenericUpdate
  def initialize(args)
    @db = args.fetch(:db)
    @table_name = args.fetch(:table_name)
    @data = args.fetch(:data)
    @terms = args.fetch(:terms)
    @buffer = args[:buffer]
  end

  def execute
    if @buffer
      @buffer.query(to_sql)
    else
      @db.query(to_sql)
    end
  end

  def to_sql
    sql = "UPDATE #{@db.quote_table(@table_name)} SET "

    first = true
    @data.each do |key, value|
      sql << ", " unless first
      first = false if first
      sql << "#{@db.quote_column(key)} = #{@db.quote_value(value)}"
    end

    sql << " WHERE #{@db.sql_make_where(@terms)}" if @terms && !@terms.empty?
    sql
  end
end
