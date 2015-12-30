class Baza::Driver::Mysql::Databases
  def initialize(args)
    @db = args.fetch(:db)
  end

  def create(args)
    sql = "CREATE DATABASE"
    sql << " IF NOT EXISTS" if args[:if_not_exists]
    sql << " `#{@db.escape_table(args.fetch(:name))}`"

    @db.query(sql)
    true
  end

  def [](name)
    name = name.to_s
    list.each do |database|
      return database if database.name == name
    end

    raise Baza::Errors::DatabaseNotFound
  end

  def list
    ArrayEnumerator.new do |yielder|
      @db.query("SHOW DATABASES") do |data|
        yielder << Baza::Driver::Mysql::Database.new(
          name: data.fetch(:Database),
          driver: self,
          db: @db
        )
      end
    end
  end
end
