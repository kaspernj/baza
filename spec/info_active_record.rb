require "active_record"

class Baza::InfoActive_record
  def self.sample_db
    active_record_connection = ::ActiveRecord::Base.establish_connection(
      adapter: "mysql2",
      host: "localhost",
      database: "baza-test",
      username: "baza-test",
      password: "BBH7djRUKzL5nmG3"
    )

    db = Baza::Db.from_object(active_record_connection)

    db.tables.list.each do |name, table|
      table.drop
    end

    begin
      yield db
    ensure
      db.close
    end
  end
end
