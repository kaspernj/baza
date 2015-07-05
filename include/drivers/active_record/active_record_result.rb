class Baza::Driver::ActiveRecord::Result < Baza::ResultBase
  def initialize(res)
    @res = res
  end

  def fetch
    begin
      return to_enum.next
    rescue StopIteration
      return false
    end
  end

  def each(&blk)
    return unless @res

    if RUBY_ENGINE == "jruby"
      @res.each do |result|
        yield result.symbolize_keys
      end
    else
      @res.each(as: :hash) do |result|
        yield result.symbolize_keys
      end
    end
  end
end
