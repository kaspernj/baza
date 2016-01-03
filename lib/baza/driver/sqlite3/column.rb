# This class handels all the SQLite3-columns.
class Baza::Driver::Sqlite3::Column < Baza::Column
  attr_reader :args

  # Constructor. This should not be called manually.
  def initialize(args)
    @args = args
    @data = args.fetch(:data)
    @db = @args.fetch(:db)
  end

  # Returns the name of the column.
  def name
    @data.fetch(:name)
  end

  def table_name
    @args.fetch(:table_name)
  end

  # Returns the columns table-object.
  def table
    @db.tables[table_name]
  end

  # Returns the data of the column as a hash in knjdb-format.
  def data
    {
      type: type,
      name: name,
      null: null?,
      maxlength: maxlength,
      default: default,
      primarykey: primarykey?,
      autoincr: autoincr?
    }
  end

  # Returns the type of the column.
  def type
    unless @type
      if match = @data.fetch(:type).match(/^([A-z]+)$/)
        @maxlength = false
        type = match[0].downcase.to_sym
      elsif match = @data.fetch(:type).match(/^decimal\((\d+),(\d+)\)$/)
        @maxlength = "#{match[1]},#{match[2]}"
        type = :decimal
      elsif match = @data.fetch(:type).match(/^enum\((.+)\)$/)
        @maxlength = match[1]
        type = :enum
      elsif match = @data.fetch(:type).match(/^(.+)\((\d+)\)$/)
        @maxlength = match[2]
        type = match[1].to_sym
      elsif @data.key?(:type) && @data.fetch(:type).to_s == ""
        return @data[:type] # A type can actually be empty in SQLite... Wtf?
      end

      if type == :integer
        @type = :int
      else
        @type = type
      end

      raise "Still not type? (#{@data})" if @type.to_s.strip.empty?
    end

    @type
  end

  # Returns true if the column allows null. Otherwise false.
  def null?
    return false if @data.fetch(:notnull).to_i == 1
    true
  end

  # Returns the maxlength of the column.
  def maxlength
    type unless @maxlength.nil?
    return @maxlength if @maxlength
    false
  end

  # Returns the default value of the column.
  def default
    def_val = @data.fetch(:dflt_value)

    if def_val && (match = def_val.match(/\A'(.*)'\Z/))
      return match[1]
    end

    return nil if @data.fetch(:dflt_value).to_s.empty?
    def_val
  end

  # Returns true if the column is the primary key.
  def primarykey?
    @data.fetch(:pk).to_i == 1
  end

  # Returns true if the column is auto-increasing.
  def autoincr?
    primarykey? && @data.fetch(:type).downcase == "integer"
  end

  # Drops the column from the table.
  def drop
    table.copy(drops: name)
  end

  def reload
    @db.q("PRAGMA table_info(`#{@db.escape_table(table_name)}`)") do |data|
      next unless data.fetch(:name) == name
      @data = data
      @type = nil
      return nil
    end

    raise Baza::Errors::ColumnNotFound, "Could not find data for column: #{table_name}.#{name}"
  end

  # Changes data on the column. Like the name, type, maxlength or whatever.
  def change(data)
    newdata = data.clone

    newdata[:name] = name unless newdata.key?(:name)
    newdata[:type] = type unless newdata.key?(:type)
    newdata[:maxlength] = maxlength unless newdata.key?(:maxlength) && maxlength
    newdata[:null] = null? unless newdata.key?(:null)
    newdata[:default] = default unless newdata.key?(:default)
    newdata[:primarykey] = primarykey? unless newdata.key?(:primarykey)

    @type = nil
    @maxlength = nil

    new_table = table.copy(
      alter_columns: {
        name => newdata
      }
    )

    @data[:name] = newdata.fetch(:name).to_s
    reload
  end
end
