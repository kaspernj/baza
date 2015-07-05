class Baza::Cloner
  def self.from_active_record_connection(connection)
    if connection.class.name.match('Mysql(2?)Adapter')
      connection = connection.instance_variable_get(:@connection)

      config = connection.instance_variable_get(:@query_options)
      config ||= connection.instance_variable_get(:@config)

      db_args = {
        type: :mysql,
        host: config[:host],
        user: config[:username],
        pass: config[:password],
        db: config[:database]
      }

      db_args[:subtype] = :mysql2 if connection.class.name.include?('Mysql2Adapter')

      Baza::Db.new(db_args)
    else
      raise "Unsupported adapter: #{connection.class.name}"
    end
  end
end
