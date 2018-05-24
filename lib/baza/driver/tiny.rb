class Baza::Driver::Tiny < Baza::BaseSqlDriver
  def initialize(db)
    super

    @client = TinyTds::Client.new(username: db.opts.fetch(:user), password: db.opts.fetch(:pass), host: db.opts.fetch(:host))
  end

  def close
    @client.close
  end

  def query(sql)
    result = @client.execute(sql)
    Baza::Driver::Tiny::Result.new(result)
  end
end
