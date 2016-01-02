class Baza::Driver::Mysql::Databases
  def initialize(args)
    @db = args.fetch(:db)
  end

  def create(args)
    sql = "CREATE DATABASE"
    sql << " IF NOT EXISTS" if args[:if_not_exists]
    sql << " #{@db.sep_database}#{@db.escape_table(args.fetch(:name))}#{@db.sep_database}"

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
    @db.query("USE #{@db.sep_database}#{@db.escape_database(name)}#{@db.sep_database}")

    if block_given?
      begin
        yield
      ensure
        @db.query("USE #{@db.sep_database}#{@db.escape_database(previous_db_name)}#{@db.sep_database}")
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
