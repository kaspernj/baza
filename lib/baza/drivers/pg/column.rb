class Baza::Driver::Pg::Column < Baza::Column
  attr_reader :name

  def initialize(args)
    @db = args.fetch(:db)
    @data = args.fetch(:data)
    @name = @data.fetch(:column_name)
  end

  def table_name
    @data.fetch(:table_name)
  end

  def type
    unless @type
      type = @data.fetch(:udt_name)

      if type == "int4"
        @type = :int
      else
        @type = type.to_sym
      end
    end

    @type
  end

  def maxlength
    @data.fetch(:character_maximum_length)
  end

  def null?
    @data.fetch(:is_nullable) == "YES"
  end

  def primarykey?
    autoincr?
  end

  def autoincr?
    !@data.fetch(:column_default).to_s.match(/\Anextval\('#{Regexp.escape(table_name)}_#{Regexp.escape(name)}_seq'::regclass\)\Z/).nil?
  end

  def default
    return nil if autoincr?
    @data.fetch(:column_default)
  end

  def drop
    @db.query("ALTER TABLE #{@db.sep_table}#{@db.escape_table(table_name)}#{@db.sep_table} DROP COLUMN #{@db.sep_col}#{@db.escape_column(name)}#{@db.sep_col}")
    nil
  end

  def reload
    data = @db.single([:information_schema, :columns], table_name: table_name, column_name: name)
    raise Baza::Errors::ColumnNotFound unless data
    @data = data
  end

  def change(data)
    if data.key?(:name) && data.fetch(:name).to_s != name
      @db.query("#{alter_table_sql} RENAME #{col_escaped} TO #{@db.sep_col}#{@db.escape_column(data.fetch(:name))}#{@db.sep_col}")
      @name = data.fetch(:name).to_s
    end

    change_type = true if data.key?(:type) && data.fetch(:type).to_s != type.to_s
    change_type = true if data.key?(:maxlength) && data.fetch(:maxlength) != maxlength

    if change_type
      type = data[:type].to_s || type.to_s

      if type == "int"
        using = " USING (trim(#{name})::integer)"
      else
        using = ""
      end

      @db.query("#{alter_column_sql} TYPE #{data.fetch(:type)}#{using}")
      @type = nil
      changed = true
    end

    if data.key?(:null) && data.fetch(:null) != null?
      if data.fetch(:null)
        @db.query("#{alter_column_sql} DROP NOT NULL")
      else
        @db.query("#{alter_column_sql} ADD NOT NULL")
      end

      changed = true
    end

    if data.key?(:default) && data.fetch(:default) != default
      if data.fetch(:default).nil?
        default = "NULL"
        @db.query("#{alter_column_sql} DROP DEFAULT")
      else
        default = "'#{@db.esc(data.fetch(:default))}'"
        @db.query("#{alter_column_sql} SET DEFAULT #{default}")
      end

      changed = true
    end

    reload if changed
    self
  end

private

  def col_escaped
    "#{@db.sep_col}#{@db.escape_column(name)}#{@db.sep_col}"
  end

  def table_escaped
    "#{@db.sep_table}#{@db.escape_table(table_name)}#{@db.sep_table}"
  end

  def alter_table_sql
    "ALTER TABLE #{table_escaped}"
  end

  def alter_column_sql
    "#{alter_table_sql} ALTER COLUMN #{col_escaped}"
  end
end
