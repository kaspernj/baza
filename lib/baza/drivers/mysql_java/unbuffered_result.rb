#This class controls the unbuffered result for the normal MySQL-driver.
class Baza::Driver::Mysql::UnbufferedResult < Baza::ResultBase
  #Constructor. This should not be called manually.
  def initialize(conn, opts, result)
    raise 'stub'
  end

  #Returns a single result.
  def fetch
    raise 'stub'
  end

  #Loops over every single result yielding it.
  def each
    raise 'stub'
  end
end
