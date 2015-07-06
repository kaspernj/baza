#This class controls the result for the MySQL2 driver.
class Baza::Driver::Mysql2::Result < Baza::ResultBase
  #Constructor. This should not be called manually.
  def initialize(result)
    @result = result
  end

  #Returns a single result.
  def fetch
    @enum = @result.to_enum if !@enum

    begin
      return @enum.next
    rescue StopIteration
      return false
    end
  end

  #Loops over every single result yielding it.
  def each
    @result.each do |res|
      next unless res #This sometimes happens when streaming results...
      yield res
    end
  end
end
