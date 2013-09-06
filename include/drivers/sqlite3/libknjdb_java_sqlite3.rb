class KnjDB_java_sqlite3
  def escape_table
    return "`"
  end
  
  def escape_col
    return "`"
  end
  
  def escape_val
    return "'"
  end
  
  def initialize(baza_db_obj)
    @baza_db = baza_db_obj
    
    if @baza_db.opts[:sqlite_driver]
      require @baza_db.opts[:sqlite_driver]
    else
      require File.dirname(__FILE__) + "/sqlitejdbc-v056.jar"
    end
    
    require "java"
    import "org.sqlite.JDBC"
    @conn = java.sql.DriverManager::getConnection("jdbc:sqlite:" + @baza_db.opts[:path])
    @stat = @conn.createStatement
  end
  
  def query(string)
    begin
      return KnjDB_java_sqlite3_result.new(@stat.executeQuery(string))
    rescue java.sql.SQLException => e
      if e.message == "java.sql.SQLException: query does not return ResultSet"
        #ignore it.
      else
        raise e
      end
    end
  end
  
  def fetch(result)
    return result.fetch
  end
  
  def escape(string)
    if (!string)
      return ""
    end
    
      string = string.gsub("'", "\\'")
    return string
  end
  
  def lastID
    return @conn.last_insert_row_id
  end
end

class KnjDB_java_sqlite3_result
  def initialize(rs)
    @rs = rs
    @index = 0
    
    if rs
      @metadata = rs.getMetaData
      @columns_count = @metadata.getColumnCount
    end
  end
  
  def fetch
    if !@rs.next
      return false
    end
    
    tha_return = {}
    for i in (1..@columns_count)
      col_name = @metadata.getColumnName(i)
      tha_return.store(col_name, @rs.getString(i))
    end
    
    return tha_return
  end
end