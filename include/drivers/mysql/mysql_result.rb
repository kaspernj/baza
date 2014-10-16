#This class controls the results for the normal MySQL-driver.
class Baza::Driver::Mysql::Result
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

    ret = {}
    count = 0
    @keys.each do |key|
      ret[key] = fetched[count]
      count += 1
    end

    return ret
  end

  #Loops over every result yielding it.
  def each
    while data = self.fetch
      yield(data)
    end
  end
end
