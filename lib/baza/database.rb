class Baza::Database
  def initialize(args)
    @args = args
  end

  def baza
    @args.fetch(:baza)
  end

  def driver
    @args.fetch(:driver)
  end

  def name
    @args.fetch(:name)
  end

  def tables
    ArrayEnumerator.new do |yielder|
      baza.tables.list(database: name) do |table|
        yielder << table
      end
    end
  end

  def table(name)
    baza.tables[name]
  end
end
