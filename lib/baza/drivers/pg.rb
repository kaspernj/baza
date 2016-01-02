class Baza::Driver::Pg < Baza::BaseSqlDriver
  path = "#{File.dirname(__FILE__)}/pg"

  autoload :Database, "#{path}/database"
  autoload :Databases, "#{path}/databases"
  autoload :Table, "#{path}/table"
  autoload :Tables, "#{path}/tables"
  autoload :Column, "#{path}/column"
  autoload :Columns, "#{path}/columns"
  autoload :Index, "#{path}/index"
  autoload :Indexes, "#{path}/indexes"
  autoload :Result, "#{path}/result"
  autoload :UnbufferedResult, "#{path}/unbuffered_result"
  autoload :Sqlspecs, "#{path}/sqlspecs"

  attr_reader :conn

  def self.from_object(args)
    if args[:object].class.name == "PG::Connection"
      return {
        type: :success,
        args: {
          type: :pg,
          conn: args[:object]
        }
      }
    end

    nil
  end

  def self.args
    [{
      label: "Host",
      name: "host"
    }, {
      label: "Port",
      name: "port"
    }, {
      label: "Username",
      name: "user"
    }, {
      label: "Password",
      name: "pass"
    }, {
      label: "Database",
      name: "db"
    }]
  end

  def initialize(db)
    super

    @sep_database = '"'
    @sep_table = '"'
    @sep_col = '"'
    @sep_index = '"'

    if db.opts[:conn]
      @conn = db.opts.fetch(:conn)
    else
      reconnect
    end
  end

  def reconnect
    require "pg" unless ::Object.const_defined?(:PG)

    args = {dbname: db.opts.fetch(:db)}
    args[:port] = db.opts.fetch(:port) if db.opts[:port]
    args[:hostaddr] = db.opts.fetch(:host) if db.opts[:host]
    args[:user] = db.opts.fetch(:user) if db.opts[:user]
    args[:password] = db.opts.fetch(:pass) if db.opts[:pass]

    @conn = PG::Connection.new(args)
  end

  def query(sql)
    Baza::Driver::Pg::Result.new(self, @conn.exec(sql))
  end

  def query_ubuf(sql)
    @conn.send_query(sql)
    @conn.set_single_row_mode
    result = @conn.get_result
    Baza::Driver::Pg::Result.new(self, result, unbuffered: true)
  end

  def close
    @conn.close
  end
end
