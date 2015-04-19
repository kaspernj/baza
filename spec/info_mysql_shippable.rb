class Baza::InfoMysql
  attr_reader :db

  def initialize
    if RUBY_ENGINE == "jruby"
      @db = Baza::Db.new(
        type: :mysql,
        host: "localhost",
        user: "shippa",
        db: "baza"
      )
    else
      @db = Baza::Db.new(
        type: :mysql,
        subtype: :mysql2,
        host: "localhost",
        user: "shippa",
        db: "baza"
      )
    end
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
