require "Mono.Data.Sqlite, Version=2.0.0.0, Culture=neutral, PublicKeyToken=0738eb9f132ed756"
require "Mono.Data.SqliteClient, Version=2.0.0.0, Culture=neutral, PublicKeyToken=0738eb9f132ed756"

class Baza::Driver::Sqlite3_ironruby
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
    @conn = Mono::Data::SqliteClient::SqliteConnection.new("URI=file:" + @baza_db.opts[:path] + ",version=3")
    @conn.Open
  end
  
  def query(string)
    dbcmd = @conn.CreateCommand
    dbcmd.CommandText = string
    reader = dbcmd.ExecuteReader
    return Baza::Driver::Sqlite3_ironruby_result.new(reader)
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

class Baza::Driver::Sqlite3_ironruby_result
  def initialize(reader)
    @reader = reader
  end
  
  def fetch
    if !@reader.Read
      return false
    end
    
    ret = {}
    
    count = 0
    while true
      begin
        ret[@reader.get_name(count)] = @reader.get_string(count)
      rescue IndexError => e
        break
      end
      
      count += 1
    end
    
    return ret
  end
end