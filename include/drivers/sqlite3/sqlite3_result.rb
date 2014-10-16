#This class handels the result when running MRI (or others).
class Baza::Driver::Sqlite3::Result
  #Constructor. This should not be called manually.
  def initialize(driver, result_array)
    @result_array = result_array
    @index = 0
  end

  #Returns a single result.
  def fetch
    result_hash = @result_array[@index]
    return false unless result_hash
    @index += 1

    ret = {}
    result_hash.each do |key, val|
      if (Float(key) rescue false)
        #do nothing.
      elsif !key.is_a?(Symbol)
        ret[key.to_sym] = val
      else
        ret[key] = val
      end
    end

    return ret
  end

  #Loops over every result yielding them.
  def each
    while data = self.fetch
      yield(data)
    end
  end
end
