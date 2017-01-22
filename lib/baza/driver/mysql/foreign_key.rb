class Baza::Driver::Mysql::ForeignKey < Baza::ForeignKey
  def initialize(args)
    @db = args.fetch(:db)

    data = args.fetch(:data)

    @column_name = data.fetch(:COLUMN_NAME)
    @name = data.fetch(:CONSTRAINT_NAME)
    @table_name = data.fetch(:TABLE_NAME)
  end

  def drop
    @db.query("
      ALTER TABLE `#{@db.escape_table(table_name)}`
      DROP FOREIGN KEY `#{@db.escape_table(name)}`
    ")
    true
  end
end
