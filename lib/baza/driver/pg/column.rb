class Baza::Driver::Pg::Column < Baza::Column
  attr_reader :name

  def initialize(args)
    @db = args.fetch(:db)
    @data = args.fetch(:data)
    @name = @data.fetch(:column_name)
  end

  def table_name
    @_table_name ||= @data.fetch(:table_name)
  end

  def create_foreign_key(args)
    fk_name = args[:name]
    fk_name ||= "fk_#{table_name}_#{name}"

    other_column = args.fetch(:column)
    other_table = other_column.table

    sql = "
      ALTER TABLE #{@db.quote_table(table_name)}
      ADD CONSTRAINT #{@db.escape_table(fk_name)}
      FOREIGN KEY (#{@db.escape_table(name)})
      REFERENCES #{@db.escape_table(other_table.name)} (#{@db.escape_column(other_column.name)})
    "

    @db.query(sql)

    true
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
    @db.query("ALTER TABLE #{@db.quote_table(table_name)} DROP COLUMN #{@db.quote_column(name)}")
    nil
  end

  def reload
    data = @db.single([:information_schema, :columns], table_name: table_name, column_name: name)
    raise Baza::Errors::ColumnNotFound unless data
    @data = data
  end

  def change(data)
    if data.key?(:name) && data.fetch(:name).to_s != name
      @db.query("#{alter_table_sql} RENAME #{@db.quote_column(name)} TO #{@db.quote_column(data.fetch(:name))}")
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

  def alter_table_sql
    "ALTER TABLE #{@db.quote_table(table_name)}"
  end

  def alter_column_sql
    "#{alter_table_sql} ALTER COLUMN #{@db.quote_column(name)}"
  end
end
