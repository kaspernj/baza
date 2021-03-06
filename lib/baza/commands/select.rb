class Baza::Commands::Select
  def initialize(args)
    @args = args.fetch(:args)
    @block = args.fetch(:block)
    @db = args.fetch(:db)
    @sql = ""
    @table_name = args.fetch(:table_name)
    @terms = args.fetch(:terms)
  end

  def execute
    # Give 'cloned_ubuf' argument to 'q'-method.
    if @args
      @args_q = {cloned_ubuf: true} if @args[:cloned_ubuf]
      @args_q = {unbuffered: true} if @args[:unbuffered]
    end

    add_select_sql
    add_terms_sql
    add_order_sql
    add_limit_sql unless @db.mssql?

    result = execute_query

    # Return result if a block wasnt given.
    if @block
      nil
    else
      result
    end
  end

private

  def add_select_sql
    # Set up IDQuery-stuff if that is given in arguments.
    if @args && @args[:idquery]
      if @args.fetch(:idquery) == true
        select_sql = "#{@db.quote_column(:id)}"
        @col = :id
      else
        select_sql = "#{@db.quote_column(@args.fetch(:idquery))}"
        @col = @args.fetch(:idquery)
      end
    end

    select_sql ||= "*"
    @sql << "SELECT"
    @sql << top_sql if @db.mssql?
    @sql << " #{select_sql} FROM"

    if @table_name.is_a?(Array)
      @sql << " #{@db.quote_table(@table_name.first)}.#{@db.quote_table(@table_name.last)}"
    else
      @sql << " #{@db.quote_table(@table_name)}"
    end
  end

  def add_terms_sql
    @sql << " WHERE #{@db.sql_make_where(@terms)}" if !@terms.nil? && !@terms.empty?
  end

  def add_order_sql
    return if @args.nil?

    if @args[:orderby]
      @sql << " ORDER BY"

      if @args.fetch(:orderby).is_a?(Array)
        first = true
        @args.fetch(:orderby).each do |order_by|
          @sql << "," unless first
          first = false if first
          @sql << " #{@db.quote_column(order_by)}"
        end
      else
        @sql << " #{@db.quote_column(@args.fetch(:orderby))}"
      end
    end
  end

  def add_limit_sql
    return if @args.nil?

    @sql << " LIMIT #{@args[:limit]}" if @args[:limit]

    if @args[:limit_from] && @args[:limit_to]
      begin
        Float(@args[:limit_from])
      rescue
        raise "'limit_from' was not numeric: '#{@args.fetch(:limit_from)}'."
      end

      begin
        Float(@args[:limit_to])
      rescue
        raise "'limit_to' was not numeric: '#{@args[:limit_to]}'."
      end

      @sql << " LIMIT #{@args.fetch(:limit_from)}, #{@args.fetch(:limit_to)}"
    end
  end

  def top_sql
    return unless @args[:limit]
    " TOP #{@args[:limit].to_i}"
  end

  def execute_query
    # Do IDQuery if given in arguments.
    if @args && @args[:idquery]
      Baza::Idquery.new(db: @db, table: @table_name, query: @sql, col: @col, &@block)
    else
      @db.q(@sql, @args_q, &@block)
    end
  end
end
