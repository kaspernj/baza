# This class handels every MySQL-column, that can be returned from a table-object.
class Baza::Driver::Mysql::Column < Baza::Column
  attr_reader :args, :name

  # Constructor. Should not be called manually.
  def initialize(args)
    @args = args
    @data = @args.delete(:data)
    @name = @data.fetch(:Field)
    @db = @args.fetch(:db)
  end

  # Used to validate in Wref::Map.
  def __object_unique_id__
    @name
  end

  def table_name
    @args.fetch(:table_name)
  end

  # Returns the table-object that this column belongs to.
  def table
    @db.tables[table_name]
  end

  # Returns all data of the column in the knjdb-format.
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

  def reload
    data = @db.query("SHOW FULL COLUMNS FROM `#{@db.escape_table(table_name)}` WHERE `Field` = '#{@db.esc(name)}'").fetch
    raise Baza::Errors::ColumnNotFound unless data
    @data = data
    @type = nil
  end

  # Returns the type of the column (integer, varchar etc.).
  def type
    unless @type
      if match = @data[:Type].match(/^([A-z]+)$/)
        @maxlength = false
        @type = match[0].to_sym
      elsif match = @data[:Type].match(/^decimal\((\d+),(\d+)\)$/)
        @maxlength = "#{match[1]},#{match[2]}"
        @type = :decimal
      elsif match = @data[:Type].match(/^enum\((.+)\)$/)
        @maxlength = match[1]
        @type = :enum
      elsif match = @data[:Type].match(/^(.+)\((\d+)\)/)
        @maxlength = match[2].to_i
        @type = match[1].to_sym
      end

      raise "Still not type from: '#{@data[:Type]}'." if @type.to_s.strip.empty?
    end

    @type
  end

  # Return true if the columns allows null. Otherwise false.
  def null?
    return false if @data[:Null] == "NO"
    true
  end

  # Returns the maxlength.
  def maxlength
    type unless @maxlength
    return @maxlength if @maxlength
    false
  end

  # Returns the default value for the column.
  def default
    return false if (type == :datetime || type == :date) && @data[:Default].to_s.strip.empty?
    return false if (type == :int || type == :bigint) && @data[:Default].to_s.strip.empty?
    return false unless @data[:Default]
    @data.fetch(:Default)
  end

  # Returns true if the column is the primary key. Otherwise false.
  def primarykey?
    return true if @data.fetch(:Key) == "PRI"
    false
  end

  # Returns true if the column is auto-increasing. Otherwise false.
  def autoincr?
    return true if @data.fetch(:Extra).include?("auto_increment")
    false
  end

  # Returns the comment for the column.
  def comment
    @data.fetch(:Comment)
  end

  # Drops the column from the table.
  def drop
    @db.query("ALTER TABLE `#{@db.escape_table(table_name)}` DROP COLUMN `#{@db.escape_column(name)}`")
    table.__send__(:remove_column_from_list, self)
    nil
  end

  # Changes the column properties by the given hash.
  def change(data)
    col_escaped = "`#{@db.escape_column(name)}`"
    table_escape = "`#{@db.escape_table(table_name)}`"
    newdata = data.clone

    newdata[:name] = name unless newdata.key?(:name)
    newdata[:type] = type unless newdata.key?(:type)
    newdata[:maxlength] = maxlength if !newdata.key?(:maxlength) && maxlength
    newdata[:null] = null? unless newdata.key?(:null)
    newdata[:default] = default if !newdata.key?(:default) && default
    newdata.delete(:primarykey) if newdata.key?(:primarykey)

    drop_add = true if name.to_s != newdata[:name].to_s

    table.__send__(:remove_column_from_list, self) if drop_add
    @db.query("ALTER TABLE #{table_escape} CHANGE #{col_escaped} #{@db.cols.data_sql(newdata)}")
    @name = newdata[:name].to_s
    reload
    table.__send__(:add_column_to_list, self) if drop_add
  end
end
