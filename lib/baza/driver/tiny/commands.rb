class Baza::Driver::Tiny::Commands
  def initialize(db:)
    @db = db
  end

  def last_id
    @db.query("SELECT SCOPE_IDENTITY() AS id").first.fetch(:id)
  end
end
