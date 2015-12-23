class Baza::Driver::Mysql::Index < Baza::Index
  attr_reader :args, :columns

  def initialize(args)
    @args = args
    @columns = []
  end

  # Used to validate in Wref::Map.
  def __object_unique_id__
    @args.fetch(:data).fetch(:Key_name)
  end

  def name
    @args.fetch(:data).fetch(:Key_name)
  end

  def table
    @args.fetch(:db).tables[@args.fetch(:table_name)]
  end

  def drop
    sql = "DROP INDEX `#{name}` ON `#{table.name}`"

    begin
      @args.fetch(:db).query(sql)
    rescue => e
      # The index has already been dropped - ignore.
      raise e if e.message.index("check that column/key exists") == nil
    end
  end

  def rename(newname)
    newname = newname.to_sym
    create_args = data
    create_args[:name] = newname

    drop
    table.create_indexes([create_args])
    @args[:data][:Key_name] = newname
  end

  def data
    {
      name: name,
      columns: @columns
    }
  end

  # Returns true if the index is a unique-index.
  def unique?
    if @args.fetch(:data).fetch(:Index_type) == "UNIQUE" || @args.fetch(:data).fetch(:Non_unique).to_i == 0
      return true
    else
      return false
    end
  end

  # Returns true if the index is a primary-index.
  def primary?
    return true if @args.fetch(:data).fetch(:Key_name) == "PRIMARY"
    false
  end

  def reload
    data = @db.query("SHOW INDEX FROM `#{@db.esc_table(name)}` WHERE `Key_name` = '#{@db.esc(args[:name])}'").fetch
    raise Baza::Errors::IndexNotFound unless data
    @args[:data] = data
    self
  end
end
