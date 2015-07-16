# This class controls the result for the Java-MySQL-driver.
class Baza::JdbcResult < Baza::ResultBase
  INT_TYPES = {-6 => true, -5 => true, 4 => true, 5 => true}
  FLOAT_TYPES = {2 => true, 3 => true, 7 => true, 8 => true}
  TIME_TYPES = {93 => true}
  DATE_TYPES = {91 => true}
  STRING_TYPES = {-1 => true, 1 => true, 12 => true}
  NIL_TYPES = {0 => true}

  # Constructor. This should not be called manually.
  def initialize(driver, stmt, result_set, preload_results)
    @result_set = result_set
    @stmt = stmt
    @type_translation = driver.baza.opts[:type_translation]
    @rows = []
    @index = -1
    read_results if preload_results
  end

  def fetch
    if @read_results
      return false if @rows.empty?
      row = @rows.shift
    else
      return read_row
    end
  end

  def each
    while data = fetch
      yield data
    end
  end

private

  # Reads meta-data about the query like keys and count.
  def read_meta
    @result_set.before_first
    meta = @result_set.meta_data
    @count = meta.column_count

    @keys = []

    if @type_translation == true
      @types = []
      @type_names = []
    end

    1.upto(@count) do |count|
      @keys << meta.column_label(count).to_sym

      if @type_translation == true
        @types << meta.column_type(count)
        @type_names << meta.column_type_name(count).downcase.to_sym
      end
    end
  end

  def read_results
    @read_results = true

    loop do
      if row = read_row
        @rows << row
      else
        break
      end
    end
  end

  def destroy
    @stmt.close
    @result_set.close
  end

  def read_row
    return false unless @result_set

    unless @result_set.next
      destroy
      @result_set = nil
      return false
    end

    read_meta unless @keys

    hash = {}
    @count.times do |count|
      if @type_translation
        value = translate_type(@result_set, count)
      else
        value = @result_set.object(count + 1)
      end

      hash[@keys[count]] = value
    end

    return hash
  end

  def translate_type(result, count)
    java_count = count + 1

    return result.string(java_count) if @type_translation == :string

    type = @types[count]

    if INT_TYPES[type]
      return result.int(java_count)
    elsif STRING_TYPES[type]
      return result.string(java_count)
    elsif FLOAT_TYPES[type]
      return result.float(java_count)
    elsif TIME_TYPES[type] || @type_names[count] == :datetime # Important to do both in SQLite...
      return Time.parse(result.string(java_count))
    elsif DATE_TYPES[type]
      return Date.parse(result.string(java_count))
    elsif NIL_TYPES[type]
      return nil
    else
      return result.object(java_count)
    end
  end
end
