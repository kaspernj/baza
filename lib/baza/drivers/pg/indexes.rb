class Baza::Driver::Pg::Indexes
  def initialize(args)
    @db = args.fetch(:db)
  end
end
