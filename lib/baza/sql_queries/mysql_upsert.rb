class Baza::SqlQueries::MysqlUpsert
  def initialize(args)
    @db = args.fetch(:db)
    @table_name = args.fetch(:table_name)
    @updates = args.fetch(:updates)
    @terms = args.fetch(:terms)
  end

  def execute
    procedure_name = "baza_upsert_#{SecureRandom.hex(5)}"

    sql = "CREATE PROCEDURE `#{@db.escape_table(procedure_name)}` () BEGIN\n"
    sql << "\tIF EXISTS(#{select_query}) THEN\n"
    sql << "\t\t#{update_sql};\n"
    sql << "\tELSE\n"
    sql << "\t\t#{insert_sql};\n"
    sql << "\tEND IF;\n"
    sql << "END;\n"

    @db.query(sql)

    begin
      @db.query("CALL `#{@db.escape_table(procedure_name)}`")
    ensure
      @db.query("DROP PROCEDURE `#{@db.escape_table(procedure_name)}`")
    end
  end

private

  def select_query
    sql = ""
    sql << "SELECT * FROM #{@db.sep_table}#{@db.escape_table(@table_name)}#{@db.sep_table} WHERE"

    first = true
    @terms.each do |column, value|
      sql << " AND" unless first
      first = false if first
      sql << " #{@db.sep_col}#{@db.escape_column(column)}#{@db.sep_col} = #{@db.sqlval(value)}"
    end

    sql
  end

  def update_sql
    sql = ""
    sql << "UPDATE #{@db.sep_table}#{@db.escape_table(@table_name)}#{@db.sep_table} SET"

    first = true
    @updates.each do |column, value|
      sql << ", " unless first
      first = false if first
      sql << " #{@db.sep_col}#{@db.escape_column(column)}#{@db.sep_col} = #{@db.sqlval(value)}"
    end

    sql << " WHERE #{@db.sql_make_where(@terms)}"
    sql
  end

  def insert_sql
    @db.insert(@table_name, @updates.merge(@terms), return_sql: true)
  end
end
