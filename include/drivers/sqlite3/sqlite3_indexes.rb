class Baza::Driver::Sqlite3::Indexes
  def initialize(args)
    @args = args
  end
end

class Baza::Driver::Sqlite3::Indexes::Index
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

  def rename newname
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
      columns: @columns
    }
  end

  def column_names
    @columns
  end

  def to_s
    "#<Baza::Driver::Sqlite3::Index name: \"#{name}\", columns: #{@columns}>"
  end
end
