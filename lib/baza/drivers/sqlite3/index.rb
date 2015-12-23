class Baza::Driver::Sqlite3::Index < Baza::Index
  attr_reader :args, :columns

  def initialize(args)
    @args = args
    @columns = []
    @db = args[:db]
  end

  def name
    @args.fetch(:data).fetch(:name)
  end

  def table_name
    @args.fetch(:table_name)
  end

  def table
    @db.tables[table_name]
  end

  def drop
    @db.query("DROP INDEX `#{name}`")
  end

  def rename(newname)
    newname = newname.to_sym

    create_args = data
    create_args[:name] = newname

    drop
    table.create_indexes([create_args])
    @args[:data][:name] = newname
  end

  def data
    {
      name: name,
      unique: unique?,
      columns: @columns
    }
  end

  def column_names
    @columns
  end

  def unique?
    @args.fetch(:data).fetch(:unique).to_i == 1
  end

  def reload
    data = nil
    @db.query("PRAGMA index_list(`#{@db.esc_table(name)}`)") do |d_indexes|
      next unless d_indexes.fetch(:name) == name
      data = d_indexes
      break
    end

    raise Baza::Errors::IndexNotFound unless data
    @args[:data] = data
    self
  end
end
