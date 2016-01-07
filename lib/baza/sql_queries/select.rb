class Baza::SqlQueries::Select
  def initialize(args)
    @db = args.fetch(:db)
    @selects = []
    @froms = []
    @joins = []
    @wheres = []
    @groups = []
    @orders = []
  end

  def select(arg)
    @selects << arg
    self
  end

  def from(arg)
    @froms << arg
    self
  end

  def join(arg)
    @joins << arg
    self
  end

  def where(*args)
    @wheres << args
    self
  end

  def group(arg)
    @groups << arg
    self
  end

  def order(arg)
    @orders << arg
    self
  end

  def limit(limit)
    @limit = limit
    self
  end

  def offset(offset)
    @offset = offset
    self
  end

  def to_sql
    "#{select_sql} #{from_sql} #{where_sql} #{group_sql} #{limit_sql}"
  end

  def to_a
    each.to_a
  end

  def each(&blk)
    query(&blk)
  end

  def each_row
    query do |data|
      yield Baza::Row.new(
        db: @db,
        table: first_from,
        data: data
      )
    end
  end

  def to_enum
    Enumerator.new do |yielder|
      query do |data|
        yielder << data
      end
    end
  end

  def query(&blk)
    @db.query(to_sql, &blk)
  end

private

  def select_sql
    sql = "SELECT"

    if @selects.empty?
      sql << " *"
    else
      first = true
      @selects.each do |select|
        sql << "," unless first
        first = false if first

        if select.is_a?(Symbol)
          select << " #{@db.sep_col}#{@db.escape_column(select)}#{@db.sep_col}"
        else
          select << @db.sqlval(select)
        end
      end
    end

    sql
  end

  def from_sql
    sql = "FROM"

    first = true
    @froms.each do |from|
      sql << "," unless first
      first = false if first
      sql << " #{@db.sep_table}#{@db.escape_table(from)}#{@db.sep_table}"
    end

    sql
  end

  def first_from
    @first_from ||= @froms.first
  end

  def where_sql
    return if @wheres.empty?

    sql = " WHERE"

    first = true
    @wheres.each do |args|
      where = args.shift

      sql << " AND " unless first
      first = false if first

      if where.is_a?(Hash)
        where.each do |key, value|
          sql << "#{@db.sep_col}#{@db.escape_column(key)}#{@db.sep_col} = #{@db.sqlval(value)}"
        end
      elsif where.is_a?(String)
        sql_arg = where.clone
        args.each do |arg|
          sql_arg.sub!("?", @db.sqlval(arg))
        end

        sql << sql_arg
      else
        raise "Dont know what to do with that argument: #{where}"
      end
    end

    sql
  end

  def group_sql
    return if @groups.empty?
  end

  def limit_sql
    sql = "LIMIT #{@db.sqlval(@limit)}"
    sql << ", #{@db.sqlval(@offset)}" if @offset
    sql
  end
end
