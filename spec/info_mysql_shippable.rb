class Baza::InfoMysql
  attr_reader :db

  def initialize(args = {})
    @db = Baza::Db.new({
      type: :mysql,
      host: "localhost",
      user: "shippa",
      db: "baza"
    }.merge(args))
  end

  def before
    @db.tables.list.each do |name, table|
      table.drop
    end
  end

  def after
    @db.close
  end
end
