class Baza::Driver::Pg < Baza::BaseSqlDriver
  AutoAutoloader.autoload_sub_classes(self, __FILE__)

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
    elsif db.opts[:db]
      reconnect
    end
  end

  def connected?
    @conn ? true : false
  end

  def escape(string)
    if @conn
      @conn.escape_string(string.to_s)
    else
      PG::Connection.escape_string(string.to_s)
    end
  end

  def reconnect
    require "pg" unless ::Object.const_defined?(:PG)

    close if @conn && !@conn.finished?

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
