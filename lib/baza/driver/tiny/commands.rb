class Baza::Driver::Tiny::Commands
  def initialize(db:)
    @db = db
  end

  def last_id
    data = @db.query("SELECT SCOPE_IDENTITY() AS id").first

    puts "Data: #{data}"

    data.fetch(:id)
  end
end
