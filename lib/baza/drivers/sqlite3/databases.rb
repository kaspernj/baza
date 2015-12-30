class Baza::Driver::Sqlite3::Databases
  def initialize(args)
    @db = args.fetch(:db)
    raise "Db wasn't a baza object" unless @db.class.name.include?("Baza")
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
      yielder << Baza::Driver::Sqlite3::Database.new(
        name: "Main",
        driver: self,
        db: @db
      )
    end
  end
end
