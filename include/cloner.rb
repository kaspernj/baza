class Baza::Cloner
  def self.from_active_record_connection(connection)
    if connection.class.name.include?('Mysql2Adapter')
      config = connection.instance_variable_get(:@connection).instance_variable_get(:@query_options)

      Baza::Db.new(
        type: :mysql,
        subtype: :mysql2,
        host: config[:host],
        user: config[:username],
        pass: config[:password],
        db: config[:database]
      )
    else
      raise "Unsupported adapter: #{connection.class.name}"
    end
  end
end
