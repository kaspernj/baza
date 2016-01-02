class Baza::Cloner
  def self.from_active_record_connection(connection)
    if connection.class.name.include?("Mysql2Adapter")
      connection = connection.instance_variable_get(:@connection)

      config = connection.instance_variable_get(:@query_options)
      config ||= connection.instance_variable_get(:@config)

      db_args = {
        type: :mysql2,
        host: config[:host],
        user: config[:username],
        pass: config[:password],
        db: config[:database]
      }

      Baza::Db.new(db_args)
    elsif connection.class.name.include?("MysqlAdapter")
      connection = connection.instance_variable_get(:@connection)
      connection = connection.instance_variable_get(:@connection) if RUBY_PLATFORM == "java"

      db_args = {
        type: :mysql,
        conn: connection
      }

      Baza::Db.new(db_args)
    else
      raise "Unsupported adapter: #{connection.class.name}"
    end
  end
end
