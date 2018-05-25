class Baza::Row
  include Baza::DatabaseModelFunctionality

  attr_reader :args, :data

  def knj?
    true
  end

  def initialize(args)
    @args = {}
    args.each do |key, value|
      @args[key.to_sym] = value
    end

    @args[:col_id] ||= :id
    raise "No table given." unless @args[:table]

    if @args[:data] && (@args[:data].is_a?(Integer) || @args[:data].class.name == "Fixnum" || @args[:data].is_a?(String))
      @data = {@args[:col_id].to_sym => @args[:data].to_s}
      reload
    elsif @args[:data] && @args.fetch(:data).is_a?(Hash)
      @data = {}
      @args.fetch(:data).each do |key, value|
        key = key.to_sym unless key.class.name == "Fixnum"
        @data[key] = value
      end
    elsif @args[:id]
      @data = {}
      @data[@args[:col_id].to_sym] = @args[:id]
      reload
    else
      raise ArgumentError, "Invalid data: #{@args[:data]} (#{@args[:data].class})"
    end
  end

  def db
    @args.fetch(:db)
  end

  def ob
    return @args[:objects] if @args.key?(:objects)
    false
  end

  alias objects ob

  def reload
    last_id = id
    data = db.single(@args[:table], @args[:col_id] => id)
    unless data
      raise Errno::ENOENT, "Could not find any data for the object with ID: '#{last_id}' in the table '#{@args[:table]}'."
    end

    @data = {}
    data.each do |key, value|
      @data[key.to_sym] = value
    end
  end

  def update(newdata)
    db.update(@args.fetch(:table), newdata, @args.fetch(:col_id) => id)
    reload

    ob.call("object" => self, "signal" => "update") if ob
  end

  def delete
    db.delete(@args.fetch(:table), @args.fetch(:col_id) => id)
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
    @data.fetch(@args.fetch(:col_id))
  end

  def to_param
    id
  end

  def title
    return @data[@args.fetch(:col_title).to_sym] if @args[:col_title]

    if @data.key?(:title)
      return @data.fetch(:title)
    elsif @data.key?(:name)
      return @data.fetch(:name)
    end

    raise "'col_title' has not been set for the class: '#{self.class}'."
  end

  alias name title

  def each(*args, &blk)
    @data.each(*args, &blk)
  end

  def each_value(*args, &blk)
    @data.each_value(*args, &blk)
  end

  def to_hash
    @data.clone
  end

  def esc(str)
    db.escape(str)
  end

  def method_missing(func_name, *args)
    if (match = func_name.to_s.match(/^(\S+)\?$/)) && @data.key?(match[1].to_sym)
      if @data.fetch(match[1].to_sym) == "1" || @data.fetch(match[1].to_sym) == "yes"
        return true
      elsif @data.fetch(match[1].to_sym) == "0" || @data.fetch(match[1].to_sym) == "no"
        return false
      end
    end

    super
  end
end
