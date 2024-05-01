class Baza::Driver::Pg::Result
  def initialize(driver, result, args = nil)
    @result = result
    @unbuffered = true if args && args[:unbuffered]
    @type_translation = driver.db.opts[:type_translation]

    types
  end

  def to_enum
    @enum ||= Enumerator.new do |yielder|
      if @unbuffered
        @result.stream_each_row do |values|
          if @type_translation == :string
            values = translate_values_to_strings(values)
          elsif @type_translation
            values = translate_values_with_types(values)
          end

          result_sym = Hash[*keys.zip(values).flatten]
          yielder << result_sym
        end
      else
        @result.each do |result|
          values = result.values

          if @type_translation == :string
            values = translate_values_to_strings(values)
          elsif @type_translation
            values = translate_values_with_types(values)
          end

          result_sym = Hash[*keys.zip(values).flatten]
          yielder << result_sym
        end
      end
    end
  end

  def to_a_enum
    ArrayEnumerator.new(to_enum)
  end

  def fetch
    to_enum.next
  rescue StopIteration
    nil
  end

  def each(&blk)
    to_enum.each(&blk)
  rescue StopIteration
    nil
  end

  def to_a
    array = []
    each do |result| # rubocop:disable Style/MapIntoArray
      array << result
    end

    array
  end

private

  def keys
    unless @keys
      @keys = []
      @result.fields.each do |field|
        @keys << field.to_sym
      end
    end

    @keys
  end

  def types
    unless @types
      @types = []
      @result.fields.length.times do |count|
        type_num = @result.ftype(count)

        case type_num
        when 20, 23
          @types << :int
        when 16, 19, 25, 26, 28, 1034, 1043
          @types << :string
        when 701
          @types << :float
        when 1114
          @types << :time
        when 1082
          @types << :date
        else
          if @debug
            data = nil
            @result.each do |data_i|
              data = data_i
              break
            end

            value = data.values[count] if data

            raise "Unknown type number: #{type_num} for this field: #{@result.fields[count]}: #{value}"
          else
            @types << :string
          end
        end
      end
    end

    @types
  end

  def translate_values_with_types(values)
    values.collect!.with_index do |value, count|
      type_sym = types[count]

      if type_sym == :int
        value.to_i
      elsif type_sym == :float
        value.to_f
      elsif type_sym == :time
        if value.is_a?(Time) # ActiveRecord might already have parsed it for us
          value
        else
          Time.parse(value)
        end
      elsif type_sym == :date
        Date.parse(value)
      elsif type_sym == :string
        value
      else
        raise "Unknown type symbol: #{type_sym}"
      end
    end
  end

  def translate_values_to_strings(values)
    values.map!(&:to_s)
  end
end
