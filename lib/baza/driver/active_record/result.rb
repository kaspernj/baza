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
      # Seems like this happens depending on the version installed? - kaspernj
      result = result.delete_if { |k, _v| k.class.name == "Integer" || k.class.name == "Fixnum" }

      result = Hash[result.map { |k, v| [k, v.to_s] }] if @type_translation == :string

      yield result.symbolize_keys
    end
  end
end
