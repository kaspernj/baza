class Baza::Database
  include Baza::DatabaseModelFunctionality

  attr_reader :db, :driver, :name_was
  attr_accessor :name

  def initialize(args)
    @db = args.fetch(:db)
    @driver = args.fetch(:driver)
    @name = args.fetch(:name)
    @name_was = @name
  end

  def tables
    ArrayEnumerator.new do |yielder|
      @db.tables.list(database: name) do |table|
        yielder << table
      end
    end
  end

  def table(name)
    @db.tables[name]
  end

  def save!
    raise Baza::Errors::NotImplemented
  end

  def to_param
    name
  end
end
