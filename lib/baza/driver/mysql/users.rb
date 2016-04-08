require_relative "user"

class Baza::Driver::Mysql::Users
  def initialize(args)
    @args = args
    @db = @args.fetch(:db)
  end

  def list
    result = []
    @db.query("SELECT * FROM mysql.user") do |user_data|
      user = Baza::Driver::Mysql::User.new(
        db: @db,
        data: user_data
      )

      if block_given?
        yield user
      else
        result << user
      end
    end

    result unless block_given?
  end

  def find_by_name(name)
    list do |user|
      return user if user.name == name.to_s
    end

    raise Baza::Errors::UserNotFound, "Could not find a user by that name: #{name}"
  end

  def create(data)
    @db.query("CREATE USER '#{@db.esc(data.fetch(:name))}'@'#{@db.esc(data.fetch(:host))}' IDENTIFIED BY '#{data.fetch(:password)}'")
    find_by_name(data.fetch(:name))
  end
end
