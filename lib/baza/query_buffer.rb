# This class buffers a lot of queries and flushes them out via transactions.
class Baza::QueryBuffer
  attr_reader :thread_async

  INITIALIZE_ARGS_ALLOWED = [:db, :debug, :flush_async]
  # Constructor. Takes arguments to be used and a block.
  def initialize(args)
    @args = args
    @db = args.fetch(:db)
    @queries = []
    @inserts = {}
    @queries_count = 0
    @debug = @args[:debug]
    @lock = Mutex.new

    STDOUT.puts "Query buffer started." if @debug

    return unless block_given?

    if @args[:flush_async]
      @db.clone_conn do |db_flush_async|
        @db_flush_async = db_flush_async

        begin
          yield(self)
        ensure
          flush
          thread_async_join
        end
      end
    else
      begin
        yield(self)
      ensure
        flush
        thread_async_join
      end
    end
  end

  # Adds a query to the buffer.
  def query(str)
    @lock.synchronize do
      STDOUT.print "Adding to buffer: #{str}\n" if @debug
      @queries << str
      @queries_count += 1
    end

    flush if @queries_count >= 1000
    nil
  end

  # Delete as on a normal Baza::Db.
  #===Example
  # buffer.delete(:users, {:id => 5})
  def delete(table, where)
    STDOUT.puts "Delete called on table #{table} with arguments: '#{where}'." if @debug
    query(@db.delete(table, where, return_sql: true))
    nil
  end

  # Update as on a normal Baza::Db.
  #===Example
  # buffer.update(:users, {:name => "Kasper"}, {:id => 5})
  def update(table, update, terms)
    STDOUT.puts "Update called on table #{table}." if @debug
    query(@db.update(table, update, terms, return_sql: true))
    nil
  end

  # Shortcut to doing upsert through the buffer instead of through the db-object with the buffer as an argument.
  #===Example
  # buffer.upsert(:users, {:id => 5}, {:name => "Kasper"})
  def upsert(table, data, terms)
    @db.upsert(table, data, terms, buffer: self)
    nil
  end

  # Plans to inset a hash into a table. It will only be inserted when flush is called.
  #===Examples
  # buffer.insert(:users, {:name => "John Doe"})
  def insert(table, data)
    query(@db.insert(table, data, return_sql: true))
    nil
  end

  # Flushes all queries out in a transaction. This will automatically be called for every 1000 queries.
  def flush
    if @args[:flush_async]
      flush_async
    else
      flush_real
    end
  end

private

  # Runs the flush in a thread in the background.
  def flush_async
    thread_async_join

    @thread_async = Thread.new do
      begin
        flush_real(@db_flush_async)
      rescue => e
        $stderr.puts e.inspect
        $stderr.puts e.backtrace
      end
    end
  end

  def thread_async_join
    if thread = @thread_async
      thread.join
    end
  end

  # Flushes the queries for real.
  def flush_real(db = nil)
    return nil if @queries_count <= 0
    db = @db if db == nil

    @lock.synchronize do
      unless @queries.empty?
        until @queries.empty?
          db.transaction do
            @queries.shift(1000).each do |str|
              STDOUT.print "Executing via buffer: #{str}\n" if @debug
              db.q(str)
            end
          end
        end
      end

      @inserts.each do |table, datas_arr|
        until datas_arr.empty?
          datas_chunk_arr = datas_arr.shift(1000)
          @db.insert_multi(table, datas_chunk_arr)
        end
      end

      @inserts.clear
      @queries_count = 0
    end

    nil
  end
end
