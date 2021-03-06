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

  def count
    @count = true
    query.fetch.fetch(:count).to_i
  ensure
    @count = false
  end

  def current_page
    @page || 1
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

  def page(number)
    @page = number.try(:to_i) || 1
    self
  end

  def per_page(number)
    @per_page = number
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

  def total_pages
    @per_page ||= 30
    per_page_value = @per_page
    (count.to_f / per_page_value.to_f).ceil
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

    if @count
      sql << " COUNT(*) AS count"
    elsif @selects.empty?
      sql << " *"
    else
      first = true
      @selects.each do |select|
        sql << "," unless first
        first = false if first

        if select.is_a?(Symbol)
          select << " #{@db.quote_column(select)}"
        else
          select << @db.quote_value(select)
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
      sql << " #{@db.quote_table(from)}"
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
          sql << "#{@db.quote_column(key)} = #{@db.quote_value(value)}"
        end
      elsif where.is_a?(String)
        sql_arg = where.clone
        args.each do |arg|
          sql_arg.sub!("?", @db.quote_value(arg))
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
    unless @count
      if @page
        @per_page ||= 30
        sql = "LIMIT #{@db.quote_value(@per_page)} OFFSET #{@per_page * (current_page - 1)}"
      elsif @limit
        sql = "LIMIT #{@db.quote_value(@limit)}"
        sql << ", #{@db.quote_value(@offset)}" if @offset
      end
    end

    sql
  end
end
