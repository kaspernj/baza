class Baza::Driver::Mysql::Databases
  def initialize(args)
    @db = args.fetch(:db)
  end

  def create(if_not_exists: false, name:)
    sql = "CREATE DATABASE"
    sql << " IF NOT EXISTS" if if_not_exists
    sql << " #{@db.quote_table(name)}"

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

  def with_database(name)
    if @db.opts[:db].to_s == name.to_s
      yield if block_given?
      return self
    end

    previous_db_name = @db.current_database_name
    @db.query("USE #{@db.quote_database(name)}")

    if block_given?
      begin
        yield
      ensure
        @db.query("USE #{@db.quote_database(previous_db_name)}")
      end
    end

    self
  end

  def current_database_name
    @db.query("SELECT DATABASE()").fetch.values.first
  end

  def current_database
    @db.databases[current_database_name]
  end
end
