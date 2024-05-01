class Baza::ResultBase
  include Enumerable

  def to_enum
    @enum ||= Enumerator.new do |y|
      each do |data|
        y << data
      end
    end
  end

  def to_a_enum
    require "array_enumerator"
    @a_enum ||= ArrayEnumerator.new(to_enum)
  end

  def to_a
    map do |row_data|
      row_data
    end
  end
end
