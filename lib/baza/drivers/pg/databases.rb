class Baza::Driver::Pg::Databases
  def initialize(args)
    @db = args.fetch(:db)
  end

  def create(args)
    if args[:if_not_exists]
      begin
        __send__(:[], args.fetch(:name).to_s)
        return true
      # rubocop:disable Lint/HandleExceptions
      rescue Baza::Errors::DatabaseNotFound
        # rubocop:enable Lint/HandleExceptions
      end
    end

    @db.query("CREATE DATABASE #{@db.sep_database}#{@db.escape_table(args.fetch(:name))}#{@db.sep_database}")
    true
  end

  def [](name)
    database = list(name: name).first
    raise Baza::Errors::DatabaseNotFound unless database
    database
  end

  def list(args = {})
    where_args = {}
    where_args[:datname] = args.fetch(:name) if args[:name]

    database_list = [] unless block_given?
    @db.select(:pg_database, where_args) do |database_data|
      database = Baza::Driver::Pg::Database.new(
        db: @db,
        driver: self,
        name: database_data.fetch(:datname)
      )

      if database_list
        database_list << database
      else
        yield database
      end
    end

    database_list
  end
end
