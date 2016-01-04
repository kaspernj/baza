# This class controls the result for the MySQL2 driver.
class Baza::Driver::Mysql2::Result < Baza::ResultBase
  # Constructor. This should not be called manually.
  def initialize(driver, result)
    @result = result
    @type_translation = driver.db.opts[:type_translation]
  end

  # Returns a single result.
  def fetch
    return to_enum.next
  rescue StopIteration
    return false
  end

  # Loops over every single result yielding it.
  def each
    return unless @result

    @result.each(as: :hash, symbolize_keys: true) do |row|
      next unless row # This sometimes happens when streaming results...
      row = Hash[row.map { |k, v| [k, v.to_s] }] if @type_translation == :string
      yield row
    end
  end
end
