class Baza::Driver::Mysql::Index < Baza::Index
  attr_reader :args, :columns
  attr_accessor :table_name

  def initialize(args)
    @db = args.fetch(:db)
    @data = args.fetch(:data)
    @table_name = args.fetch(:table_name)
    @columns = []
  end

  # Used to validate in Wref::Map.
  def __object_unique_id__
    name
  end

  def name
    @data.fetch(:Key_name)
  end

  def table
    @db.tables[@table_name]
  end

  def drop
    sql = "DROP INDEX `#{name}` ON `#{@table_name}`"

    begin
      @db.query(sql)
    rescue => e
      # The index has already been dropped - ignore.
      raise e if e.message.index("check that column/key exists") == nil
    end

    self
  end

  def rename(newname)
    newname = newname.to_s
    create_args = data
    create_args[:name] = newname

    drop
    table.create_indexes([create_args])
    @data[:Key_name] = newname

    self
  end

  def data
    {
      name: name,
      columns: @columns
    }
  end

  # Returns true if the index is a unique-index.
  def unique?
    if @data.fetch(:Index_type) == "UNIQUE" || @data.fetch(:Non_unique).to_i == 0
      return true
    else
      return false
    end
  end

  # Returns true if the index is a primary-index.
  def primary?
    return true if @data.fetch(:Key_name) == "PRIMARY"
    false
  end

  def reload
    data = @db.query("SHOW INDEX FROM `#{@db.escape_table(@table_name)}` WHERE `Key_name` = '#{@db.esc(name)}'").fetch
    raise Baza::Errors::IndexNotFound unless data
    @data = data
    self
  end
end
