class Baza::Driver::Mysql::User
  attr_reader :name

  def initialize(args)
    @args = args
    @data = args.fetch(:data)
    @db = args.fetch(:db)
  end

  def name
    @data.fetch(:User)
  end

  def host
    @data.fetch(:Host)
  end

  def drop
    @db.query("DROP USER '#{@db.esc(name)}'@'#{@db.esc(host)}'")
    true
  end
end
