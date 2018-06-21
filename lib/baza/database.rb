class Baza::Database
  include Baza::DatabaseModelFunctionality

  attr_reader :db, :driver, :name

  def initialize(args)
    @changes = {}
    @db = args.fetch(:db)
    @driver = args.fetch(:driver)
    @name = args.fetch(:name)
    @name_was = @name
  end

  def import_file!(path, args = {})
    File.open(path, "r") do |io|
      use do
        Baza::Commands::Importer.new({db: @db, io: io}.merge(args)).execute
      end
    end
  end

  def name=(new_name)
    @name_was = @name
    @changes[:name] = new_name
    @name = new_name
  end

  def name_changed?
    @changes.key?(:name) && @changes.fetch(:name).to_s != name.to_s
  end

  def name_was
    @name_was
  end

  def tables(args = {})
    list_args = {database: name}
    list_args[:name] = args.fetch(:name) if args[:name]

    ArrayEnumerator.new do |yielder|
      @db.tables.list(list_args) do |table|
        yielder << table
      end
    end
  end

  def table(name)
    table = tables(name: name).first
    raise Baza::Errors::TableNotFound unless table
    table
  end

  def table_exists?(name)
    table(name)
    true
  rescue Baza::Errors::TableNotFound
    false
  end

  def save!
    raise Baza::Errors::NotImplemented
  end

  def to_param
    name
  end

  def use(&blk)
    @db.databases.with_database(name, &blk)
  end
end
