# This class takes a lot of IDs and runs a query against them.
class Baza::Idquery
  # An array containing all the IDs that will be looked up.
  attr_reader :ids

  # Constructor.
  #===Examples
  # idq = Baza::Idquery(db: db, table: :users)
  # idq.ids + [1, 5, 9]
  # idq.each do |user|
  #   print "Name: #{user[:name]}\n"
  # end
  def initialize(args, &block)
    @args = args
    @db = args.fetch(:db)
    @ids = []
    @debug = @args[:debug]

    if @args[:query]
      @db.q(@args.fetch(:query)) do |data|
        @args[:col] = data.keys.first unless @args[:col]

        if data.is_a?(Array)
          @ids << data.first
        else
          @ids << data[@args[:col]]
        end
      end
    end

    @args[:col] = :id unless @args[:col]
    @args[:size] = 200 unless @args[:size]

    if block
      raise "No query was given but a block was." unless @args[:query]
      each(&block)
    end
  end

  # Fetches results.
  #===Examples
  # data = idq.fetch #=> Hash
  def fetch
    return nil unless @args

    if @res
      data = @res.fetch if @res
      @res = nil unless data
      return data if data
    end

    @res = new_res unless @res
    unless @res
      destroy
      return nil
    end

    data = @res.fetch
    unless data
      destroy
      return nil
    end

    data
  end

  # Yields a block for every result.
  #===Examples
  # idq.each do |data|
  #   print "Name: #{data[:name]}\n"
  # end
  def each
    loop do
      data = fetch

      if data
        yield data
      else
        break
      end
    end
  end

private

  # Spawns a new database-result to read from.
  def new_res
    table_esc = @db.quote_table(@args.fetch(:table))
    col_esc = @db.quote_column(@args.fetch(:col))
    ids = @ids.shift(@args[:size])

    if ids.empty?
      destroy
      return nil
    end

    ids_sql = ids.map { |id| @db.quote_value(id) }.join(",")
    query_str = "SELECT * FROM #{table_esc} WHERE #{table_esc}.#{col_esc} IN (#{ids_sql})"
    puts "Query: #{query_str}" if @debug

    @db.q(query_str)
  end

  # Removes all variables on the object. This is done when no more results are available.
  def destroy
    @args = nil
    @ids = nil
    @debug = nil
  end
end
