class Baza::Row
  attr_reader :args, :data

  def knj?
    true
  end

  def initialize(args)
    @args = {}
    args.each do |key, value|
      @args[key.to_sym] = value
    end

    @args[:objects] = $objects if !@args[:objects] && $objects && $objects.is_a?(Baza::ModelHandler)
    @args[:col_id] = :id unless @args[:col_id]
    raise "No table given." unless @args[:table]

    if @args[:data] && (@args[:data].is_a?(Integer) || @args[:data].is_a?(Fixnum) || @args[:data].is_a?(String))
      @data = {@args[:col_id].to_sym => @args[:data].to_s}
      reload
    elsif @args[:data] && @args[:data].is_a?(Hash)
      @data = {}
      @args[:data].each do |key, value|
        @data[key.to_sym] = value
      end
    elsif @args[:id]
      @data = {}
      @data[@args[:col_id].to_sym] = @args[:id]
      reload
    else
      raise ArgumentError.new("Invalid data: #{@args[:data]} (#{@args[:data].class})")
    end
  end

  def db
    unless @args[:force_selfdb]
      curthread = Thread.current
      if curthread.is_a?(Knj::Thread) && curthread[:knjappserver] && curthread[:knjappserver][:db]
        return curthread[:knjappserver][:db]
      end
    end

    @args[:db]
  end

  def ob
    return @args[:objects] if @args.key?(:objects)
    false
  end

  alias_method :objects, :ob

  def reload
    last_id = id
    data = db.single(@args[:table], @args[:col_id] => id)
    unless data
      raise Errno::ENOENT.new("Could not find any data for the object with ID: '#{last_id}' in the table '#{@args[:table]}'.")
    end

    @data = {}
    data.each do |key, value|
      @data[key.to_sym] = value
    end
  end

  def update(newdata)
    db.update(@args[:table], newdata, @args[:col_id] => id)
    reload

    ob.call("object" => self, "signal" => "update") if ob
  end

  def delete
    db.delete(@args[:table], @args[:col_id] => id)
    destroy
  end

  def destroy
    @args = nil
    @data = nil
  end

  def key?(key)
    @data.key?(key.to_sym)
  end

  def [](key)
    raise "No valid key given." unless key
    raise "No data was loaded on the object? Maybe you are trying to call a deleted object?" unless @data

    if @data.key?(key)
      return @data[key]
    elsif @data.key?(key.to_sym)
      return @data[key.to_sym]
    elsif @data.key?(key.to_s)
      return @data[key.to_s]
    end

    raise "No such key: #{key}."
  end

  def []=(key, value)
    update(key.to_sym => value)
    reload
  end

  def id
    @data[@args[:col_id]]
  end

  def title
    return @data[@args[:col_title].to_sym] if @args[:col_title]

    if @data.key?(:title)
      return @data[:title]
    elsif @data.key?(:name)
      return @data[:name]
    end

    raise "'col_title' has not been set for the class: '#{self.class}'."
  end

  alias_method :name, :title

  def each(&args)
    @data.each(&args)
  end

  def to_hash
    @data.clone
  end

  def esc(str)
    db.escape(str)
  end

  def method_missing(*args)
    func_name = args[0].to_s
    if match = func_name.match(/^(\S+)\?$/) && @data.key?(match[1].to_sym)
      if @data[match[1].to_sym] == "1" || @data[match[1].to_sym] == "yes"
        return true
      elsif @data[match[1].to_sym] == "0" || @data[match[1].to_sym] == "no"
        return false
      end
    end

    format("No such method: %s", func_name)
  end
end
