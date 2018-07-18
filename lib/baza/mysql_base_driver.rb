class Baza::MysqlBaseDriver < Baza::BaseSqlDriver
  def self.args
    [{
      label: "Host",
      name: "host"
    }, {
      label: "Port",
      name: "port"
    }, {
      label: "Username",
      name: "user"
    }, {
      label: "Password",
      name: "pass"
    }, {
      label: "Database",
      name: "db"
    }, {
      label: "Encoding",
      name: "encoding"
    }]
  end

  # Inserts multiple rows in a table. Can return the inserted IDs if asked to in arguments.
  def insert_multi(tablename, arr_hashes, args = {})
    sql = "INSERT INTO `#{tablename}` ("

    first = true
    if args && args[:keys]
      keys = args[:keys]
    elsif arr_hashes.first.is_a?(Hash)
      keys = arr_hashes.first.keys
    else
      raise "Could not figure out keys."
    end

    keys.each do |col_name|
      sql << "," unless first
      first = false if first
      sql << quote_column(col_name)
    end

    sql << ") VALUES ("

    first = true
    arr_hashes.each do |hash|
      if first
        first = false
      else
        sql << "),("
      end

      first_key = true
      if hash.is_a?(Array)
        hash.each do |val|
          if first_key
            first_key = false
          else
            sql << ","
          end

          sql << @db.quote_value(val)
        end
      else
        hash.each do |_key, val|
          if first_key
            first_key = false
          else
            sql << ","
          end

          sql << @db.quote_value(val)
        end
      end
    end

    sql << ")"

    return sql if args && args[:return_sql]

    query(sql)

    if args && args[:return_id]
      first_id = last_id
      raise "Invalid ID: #{first_id}" if first_id.to_i <= 0
      ids = [first_id]
      1.upto(arr_hashes.length - 1) do |count|
        ids << first_id + count
      end

      ids_length = ids.length
      arr_hashes_length = arr_hashes.length
      raise "Invalid length (#{ids_length}, #{arr_hashes_length})." unless ids_length == arr_hashes_length

      return ids
    else
      return nil
    end
  end

  def transaction
    @db.q("START TRANSACTION")

    begin
      yield @db
      @db.q("COMMIT")
    rescue
      @db.q("ROLLBACK")
      raise
    end
  end
end
