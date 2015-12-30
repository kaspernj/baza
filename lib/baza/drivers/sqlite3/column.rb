# This class handels all the SQLite3-columns.
class Baza::Driver::Sqlite3::Column < Baza::Column
  attr_reader :args

  # Constructor. This should not be called manually.
  def initialize(args)
    @args = args
    @db = @args[:db]
  end

  # Returns the name of the column.
  def name
    @args[:data][:name]
  end

  def table_name
    @args[:table_name]
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
      if match = @args[:data][:type].match(/^([A-z]+)$/)
        @maxlength = false
        type = match[0].to_sym
      elsif match = @args[:data][:type].match(/^decimal\((\d+),(\d+)\)$/)
        @maxlength = "#{match[1]},#{match[2]}"
        type = :decimal
      elsif match = @args[:data][:type].match(/^enum\((.+)\)$/)
        @maxlength = match[1]
        type = :enum
      elsif match = @args[:data][:type].match(/^(.+)\((\d+)\)$/)
        @maxlength = match[2]
        type = match[1].to_sym
      elsif @args[:data].key?(:type) && @args[:data][:type].to_s == ""
        # A type can actually be empty in SQLite... Wtf?
        return @args[:data][:type]
      end

      if type == :integer
        @type = :int
      else
        @type = type
      end

      raise "Still not type? (#{@args[:data]})" if @type.to_s.strip.empty?
    end

    @type
  end

  # Returns true if the column allows null. Otherwise false.
  def null?
    return false if @args[:data][:notnull].to_i == 1
    true
  end

  # Returns the maxlength of the column.
  def maxlength
    type unless @maxlength
    return @maxlength if @maxlength
    false
  end

  # Returns the default value of the column.
  def default
    def_val = @args[:data][:dflt_value]

    if def_val && match = def_val.match(/\A'(.*)'\Z/)
      return match[1]
    end

    return false if @args[:data][:dflt_value].to_s.empty?
    def_val
  end

  # Returns true if the column is the primary key.
  def primarykey?
    return false if @args[:data][:pk].to_i == 0
    true
  end

  # Returns true if the column is auto-increasing.
  def autoincr?
    return true if @args[:data][:pk].to_i == 1 && @args[:data][:type].to_s == "integer"
    false
  end

  # Drops the column from the table.
  def drop
    table.copy(drops: name)
  end

  def reload
    @db.q("PRAGMA table_info(`#{@db.escape_table(table_name)}`)") do |data|
      next unless data.fetch(:name) == name
      @args[:data] = data
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

    @args[:data][:name] = newdata.fetch(:name).to_s
    reload
  end
end
