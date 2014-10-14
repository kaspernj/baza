class Baza::InfoMysql
  def self.sample_db
    db = Baza::Db.new(
      type: :mysql,
      subtype: :mysql2,
      host: "localhost",
      user: "shippa",
      db: "baza-test"
    )

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
