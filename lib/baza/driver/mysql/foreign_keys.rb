class Baza::Driver::Mysql::ForeignKeys < Baza::Tables
  attr_reader :db

  # Constructor. This should not be called manually.
  def initialize(db:, **args)
    @args = args
    @db = db
  end

  def create(from:, to:)
    sql = "ALTER TABLE #{from[0]} ADD FOREIGN KEY (#{from[1]}) REFERENCES #{to[0]}(#{to[1]})"

    db.query(sql)
  end
end
