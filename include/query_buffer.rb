#This class buffers a lot of queries and flushes them out via transactions.
class Baza::QueryBuffer
  attr_reader :thread_async
  
  INITIALIZE_ARGS_ALLOWED = [:db, :debug, :flush_async]
  #Constructor. Takes arguments to be used and a block.
  def initialize(args)
    @args = args
    @queries = []
    @inserts = {}
    @queries_count = 0
    @debug = @args[:debug]
    @lock = Mutex.new
    
    STDOUT.puts "Query buffer started." if @debug
    
    if block_given?
			begin
				yield(self)
			ensure
				self.flush
        thread_async_join
			end
		end
  end
  
  #Adds a query to the buffer.
  def query(str)
    @lock.synchronize do
      STDOUT.print "Adding to buffer: #{str}\n" if @debug
      @queries << str
      @queries_count += 1
    end
    
    self.flush if @queries_count >= 1000
    return nil
  end
  
  #Delete as on a normal Baza::Db.
  #===Example
  # buffer.delete(:users, {:id => 5})
  def delete(table, where)
    STDOUT.puts "Delete called on table #{table} with arguments: '#{where}'." if @debug
    self.query(@args[:db].delete(table, where, :return_sql => true))
    return nil
  end
  
  #Update as on a normal Baza::Db.
  #===Example
  # buffer.update(:users, {:name => "Kasper"}, {:id => 5})
  def update(table, update, terms)
    STDOUT.puts "Update called on table #{table}." if @debug
    self.query(@args[:db].update(table, update, terms, :return_sql => true))
    return nil
  end
  
  #Shortcut to doing upsert through the buffer instead of through the db-object with the buffer as an argument.
  #===Example
  # buffer.upsert(:users, {:id => 5}, {:name => "Kasper"})
  def upsert(table, data, terms)
    @args[:db].upsert(table, data, terms, :buffer => self)
    return nil
  end
  
  #Plans to inset a hash into a table. It will only be inserted when flush is called.
  #===Examples
  # buffer.insert(:users, {:name => "John Doe"})
  def insert(table, data)
    self.query(@args[:db].insert(table, data, :return_sql => true))
    return nil
  end
  
  #Flushes all queries out in a transaction. This will automatically be called for every 1000 queries.
  def flush
    if @args[:flush_async]
      flush_async
    else
      flush_real
    end
  end
  
  private
  
  #Runs the flush in a thread in the background.
  def flush_async
    thread_async_join
    
    @thread_async = Thread.new do
      flush_real
    end
  end
  
  def thread_async_join
    if thread = @thread_async
      thread.join
    end
  end
  
  #Flushes the queries for real.
  def flush_real
    return nil if @queries_count <= 0
    
    @lock.synchronize do
      if !@queries.empty?
        while !@queries.empty?
          @args[:db].transaction do
            @queries.shift(1000).each do |str|
              STDOUT.print "Executing via buffer: #{str}\n" if @debug
              @args[:db].q(str)
            end
          end
        end
      end
      
      @inserts.each do |table, datas_arr|
        while !datas_arr.empty?
          datas_chunk_arr = datas_arr.shift(1000)
          @args[:db].insert_multi(table, datas_chunk_arr)
        end
      end
      
      @inserts.clear
      @queries_count = 0
    end
    
    return nil
  end
end