#This class handels the result when running MRI (or others).
class Baza::Driver::Sqlite3::Result < Baza::ResultBase
  SUPPORTS_SYMBOLIZE_KEYS = {}.respond_to?(:symbolize_keys!)

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

    # This is much faster if it has been defined
    return result_hash.symbolize_keys! if result_hash.respond_to?(:symbolize_keys!)

    result_hash.keys.each do |orig_key|
      key = orig_key.to_sym rescue orig_key
      result_hash[key] = result_hash.delete(orig_key)
    end

    return result_hash
  end

  #Loops over every result yielding them.
  def each
    while data = self.fetch
      yield data
    end
  end
end
