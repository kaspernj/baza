class Baza::Driver::ActiveRecord::Result < Baza::ResultBase
  def initialize(driver, result)
    @result = result
    @type_translation = driver.db.opts[:type_translation]
  end

  def fetch
    return to_enum.next
  rescue StopIteration
    return false
  end

  def each
    return unless @result

    @result.each do |result|
      result = result.delete_if { |k, _v| k.is_a?(Fixnum) } # Seems like this happens depending on the version installed? - kaspernj
      result = Hash[result.map { |k, v| [k, v.to_s] }] if @type_translation == :string

      yield result.symbolize_keys
    end
  end
end
