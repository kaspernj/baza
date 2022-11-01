class Baza::JdbcDriver < Baza::BaseSqlDriver
  attr_reader :conn, :conns

  def initialize(db)
    @java_rs_data = {}
    @mutex = ::Mutex.new
    super
  end

  # This method handels the closing of statements and results for the Java MySQL-mode.
  def result_set_killer(id)
    data = @java_rs_data[id]
    return nil unless data

    data[:res].close
    data[:stmt].close
    @java_rs_data.delete(id)
  end

  # Executes a query and returns the result.
  def query(str)
    query_with_statement(str, @preload_results) do
      @conn.create_statement
    end
  end

  # Executes an unbuffered query and returns the result that can be used to access the data.
  def query_ubuf(str)
    query_with_statement(str, false) do
      stmt = @conn.create_statement(java.sql.ResultSet.TYPE_FORWARD_ONLY, java.sql.ResultSet.CONCUR_READ_ONLY)

      if @db.opts[:type] == :sqlite3_java
        stmt.fetch_size = 1
      else
        stmt.fetch_size = java.lang.Integer::MIN_VALUE
      end

      stmt
    end
  end

  # Closes the connection threadsafe.
  def close
    @mutex.synchronize { @conn.close }
  end

private

  def query_with_statement(sql, preload_results)
    @mutex.synchronize do
      begin
        if sql.match?(/^\s*(delete|update|create|drop|insert\s+into|alter|truncate)\s+/i)
          return query_no_result_set(sql)
        else
          stmt = yield

          result_set = stmt.execute_query(sql)
          result = Baza::JdbcResult.new(self, stmt, result_set, preload_results)

          id = result.__id__
          result_set_killer(id) if @java_rs_data.key?(id)
          @java_rs_data[id] = {res: result_set, stmt: stmt}
          ObjectSpace.define_finalizer(result, method(:result_set_killer))

          return result
        end
      rescue java.sql.SQLException => e
        result_set.close if result_set
        stmt.close if stmt
        @java_rs_data.delete(id) if result && id

        if e.message == "query does not return ResultSet"
          return query_no_result_set(sql)
        else
          raise e
        end
      end
    end
  end

  def query_no_result_set(sql)
    stmt = @conn.create_statement
    stmt.execute(sql)
    return nil
  ensure
    stmt.close if stmt
  end
end
