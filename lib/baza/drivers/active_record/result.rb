class Baza::Driver::ActiveRecord::Result < Baza::ResultBase
  def initialize(driver, res)
    @res = res
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
    return unless @res

    if RUBY_PLATFORM == "java"
      @res.each do |result|
        yield result.symbolize_keys
      end
    else
      @res.each(as: :hash) do |result|
        result = Hash[result.map { |k, v| [k, v.to_s] }] if @type_translation === :string
        yield result.symbolize_keys
      end
    end
  end
end
