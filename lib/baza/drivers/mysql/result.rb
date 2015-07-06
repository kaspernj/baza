#This class controls the results for the normal MySQL-driver.
class Baza::Driver::Mysql::Result < Baza::ResultBase
  #Constructor. This should not be called manually.
  def initialize(driver, result)
    @driver = driver
    @result = result
    @mutex = Mutex.new

    if @result
      @keys = []
      @result.fetch_fields.each do |key|
        @keys << key.name.to_sym
      end
    end
  end

  #Returns a single result as a hash with symbols as keys.
  def fetch
    fetched = nil
    @mutex.synchronize do
      fetched = @result.fetch_row
    end

    return false unless fetched
    return Hash[*@keys.zip(fetched).flatten]
  end

  #Loops over every result yielding it.
  def each
    while data = fetch
      yield data
    end
  end
end
