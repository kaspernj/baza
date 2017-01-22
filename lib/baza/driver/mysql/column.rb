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

  def create_foreign_key(args)
    fk_name = args[:name]
    fk_name ||= "fk_#{table_name}_#{name}"

    other_column = args.fetch(:column)
    other_table = other_column.table

    sql = "
      ALTER TABLE #{@db.escape_table(table_name)}
      ADD CONSTRAINT #{@db.escape_table(fk_name)}
      FOREIGN KEY (#{@db.escape_table(name)})
      REFERENCES #{@db.escape_table(other_table.name)} (#{@db.escape_column(other_column.name)})
    "

    @db.query(sql)

    true
  end

  def table_name
    @args.fetch(:table_name)
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
      if (match = @data.fetch(:Type).match(/^([A-z]+)$/))
        @maxlength = false
        @type = match[0].to_sym
      elsif (match = @data.fetch(:Type).match(/^decimal\((\d+),(\d+)\)$/))
        @maxlength = "#{match[1]},#{match[2]}"
        @type = :decimal
      elsif (match = @data.fetch(:Type).match(/^enum\((.+)\)$/))
        @maxlength = match[1]
        @type = :enum
      elsif (match = @data.fetch(:Type).match(/^(.+)\((\d+)\)/))
        @maxlength = match[2].to_i
        @type = match[1].to_sym
      end

      raise "Still no type from: '#{@data.fetch(:Type)}'" if @type.to_s.strip.empty?
    end

    @type
  end

  # Return true if the columns allows null. Otherwise false.
  def null?
    @data[:Null] != "NO"
  end

  # Returns the maxlength.
  def maxlength
    type unless @maxlength
    return @maxlength if @maxlength
    false
  end

  # Returns the default value for the column.
  def default
    return nil if (type == :datetime || type == :date) && @data[:Default].to_s.strip.empty?
    return nil if (type == :int || type == :bigint) && @data[:Default].to_s.strip.empty?
    return nil unless @data[:Default]
    @data.fetch(:Default)
  end

  # Returns true if the column is the primary key. Otherwise false.
  def primarykey?
    @data.fetch(:Key) == "PRI"
  end

  # Returns true if the column is auto-increasing. Otherwise false.
  def autoincr?
    @data.fetch(:Extra).include?("auto_increment")
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
    col_escaped = "#{@db.sep_col}#{@db.escape_column(name)}#{@db.sep_col}"
    table_escape = "#{@db.sep_table}#{@db.escape_table(table_name)}#{@db.sep_table}"
    newdata = data.clone

    newdata[:name] = name unless newdata.key?(:name)
    newdata[:type] = type unless newdata.key?(:type)
    newdata[:maxlength] = maxlength if !newdata.key?(:maxlength) && maxlength
    newdata[:null] = null? unless newdata.key?(:null)
    newdata[:default] = default if !newdata.key?(:default) && default
    newdata.delete(:primarykey) if newdata.key?(:primarykey)

    drop_add = true if name.to_s != newdata[:name].to_s

    table.__send__(:remove_column_from_list, self) if drop_add
    @db.query("ALTER TABLE #{table_escape} CHANGE #{col_escaped} #{@db.columns.data_sql(newdata)}")
    @name = newdata[:name].to_s
    reload
    table.__send__(:add_column_to_list, self) if drop_add
  end
end
