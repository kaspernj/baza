class Baza::Driver::Pg::ForeignKeys
  attr_reader :db

  def initialize(db:)
    @db = db
  end

  def create(from:, to:)
    sql = "ALTER TABLE #{from[0]} ADD FOREIGN KEY (#{from[1]}) REFERENCES #{to[0]}(#{to[1]})"

    db.query(sql)
  end
end
