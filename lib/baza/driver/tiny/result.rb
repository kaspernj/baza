class Baza::Driver::Tiny::Result < Baza::ResultBase
  def initialize(result)
    @result = result.to_a
  end

  def each(*args, &blk)
    @result.each(*args, &blk)
  end
end
