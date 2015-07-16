class Baza::Driver::ActiveRecord::Result < Baza::ResultBase
  def initialize(driver, result)
    @result = result
    @type_translation = driver.baza.opts[:type_translation]
  end

  def fetch
    begin
      return to_enum.next
    rescue StopIteration
      return false
    end
  end

  def each
    return unless @result

    @result.each do |result|
      result = Hash[result.map { |k, v| [k, v.to_s] }] if @type_translation == :string
      yield result.symbolize_keys
    end
  end
end
