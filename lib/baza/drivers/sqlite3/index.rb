class Baza::Driver::Sqlite3::Index < Baza::Index
  attr_reader :args, :columns

  def initialize(args)
    @args = args
    @columns = []
    @db = args[:db]
  end

  def name
    return @args[:data][:name]
  end

  def table_name
    return @args[:table_name]
  end

  def table
    return @db.tables[table_name]
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
    return {
      name: name,
      unique: unique?,
      columns: @columns
    }
  end

  def column_names
    @columns
  end

  def unique?
    @args[:data][:unique].to_i == 1
  end
end
