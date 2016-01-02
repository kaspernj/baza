class Baza::Driver::Pg::Index < Baza::Index
  attr_reader :name

  def initialize(args)
    @db = args.fetch(:db)
    @data = args.fetch(:data)
    @name = @data.fetch(:indexname)
  end

  def table
    @db.tables[table_name]
  end

  def table_name
    @data.fetch(:tablename)
  end

  def unique?
    @data.fetch(:indexdef).include?(" UNIQUE ")
  end

  def primary?
    name == "#{table_name}_pkey"
  end

  def rename(new_name)
    @db.query("ALTER INDEX #{@db.sep_index}#{@db.escape_index(name)}#{@db.sep_index} RENAME TO #{@db.sep_index}#{@db.escape_index(new_name)}#{@db.sep_index}")
    @name = new_name.to_s
    self
  end

  def columns
    @data.fetch(:indexdef).match(/\((.+)\)\Z/)[1].split(/\s*,\s/)
  end
end
