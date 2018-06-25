class Baza::SqlQueries::MysqlUpsert
  def initialize(args)
    @db = args.fetch(:db)
    @table_name = args.fetch(:table_name)
    @updates = args.fetch(:updates)
    @terms = args.fetch(:terms)
  end

  def execute
    procedure_name = "baza_upsert_#{SecureRandom.hex(5)}"

    sql = "CREATE PROCEDURE #{@db.quote_table(procedure_name)} () BEGIN\n"
    sql << "\tIF EXISTS(#{select_query}) THEN\n"
    sql << "\t\t#{update_sql};\n"
    sql << "\tELSE\n"
    sql << "\t\t#{insert_sql};\n"
    sql << "\tEND IF;\n"
    sql << "END;\n"

    @db.query(sql)

    begin
      @db.query("CALL #{@db.quote_table(procedure_name)}")
    ensure
      @db.query("DROP PROCEDURE #{@db.quote_table(procedure_name)}")
    end
  end

private

  def select_query
    sql = ""
    sql << "SELECT * FROM #{@db.quote_table(@table_name)} WHERE"

    first = true
    @terms.each do |column, value|
      sql << " AND" unless first
      first = false if first
      sql << " #{@db.quote_column(column)} = #{@db.quote_value(value)}"
    end

    sql
  end

  def update_sql
    @db.update(@table_name, @updates, @terms, return_sql: true)
  end

  def insert_sql
    @db.insert(@table_name, @updates.merge(@terms), return_sql: true)
  end
end
