class Baza::Driver::Tiny::Result < Baza::ResultBase
  def initialize(result)
    @result = result.to_a
  end

  def each(&blk)
    enum.each(&blk)
  end

  def fetch
    enum.next
  rescue StopIteration
    nil
  end

private

  def enum
    @enum ||= Enumerator.new do |yielder|
      @result.each do |result|
        yielder << result
      end
    end
  end
end
