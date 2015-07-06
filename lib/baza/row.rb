class Baza::Row
  attr_reader :args, :data
  
  def is_knj?; return true; end
  
  def initialize(args)
    @args = {}
    args.each do |key, value|
      @args[key.to_sym] = value
    end
    
    @args[:db] = $db if !@args[:db] and $db and $db.class.to_s == "Baza::Db"
    @args[:objects] = $objects if !@args[:objects] and $objects and $objects.is_a?(Baza::ModelHandler)
    @args[:col_id] = :id if !@args[:col_id]
    raise "No table given." if !@args[:table]
    
    if @args[:data] and (@args[:data].is_a?(Integer) or @args[:data].is_a?(Fixnum) or @args[:data].is_a?(String))
      @data = {@args[:col_id].to_sym => @args[:data].to_s}
      self.reload
    elsif @args[:data] and @args[:data].is_a?(Hash)
      @data = {}
      @args[:data].each do |key, value|
        @data[key.to_sym] = value
      end
    elsif @args[:id]
      @data = {}
      @data[@args[:col_id].to_sym] = @args[:id]
      self.reload
    else
      raise ArgumentError.new("Invalid data: #{@args[:data].to_s} (#{@args[:data].class.to_s})")
    end
  end
  
  def db
    if !@args[:force_selfdb]
      curthread = Thread.current
      if curthread.is_a?(Knj::Thread) and curthread[:knjappserver] and curthread[:knjappserver][:db]
        return curthread[:knjappserver][:db]
      end
    end
    
    return @args[:db]
  end
  
  def ob
    return @args[:objects] if @args.key?(:objects)
    return $ob if $ob and $ob.is_a?(Baza::ModelHandler)
    return false
  end
  
  alias :objects :ob
  
  def reload
    last_id = self.id
    data = self.db.single(@args[:table], {@args[:col_id] => self.id})
    if !data
      raise Errno::ENOENT.new("Could not find any data for the object with ID: '#{last_id}' in the table '#{@args[:table].to_s}'.")
    end
    
    @data = {}
    data.each do |key, value|
      @data[key.to_sym] = value
    end
  end
  
  def update(newdata)
    self.db.update(@args[:table], newdata, {@args[:col_id] => self.id})
    self.reload
    
    if self.ob
      self.ob.call("object" => self, "signal" => "update")
    end
  end
  
  def delete
    self.db.delete(@args[:table], {@args[:col_id] => self.id})
    self.destroy
  end
  
  def destroy
    @args = nil
    @data = nil
  end
  
  def has_key?(key)
    return @data.key?(key.to_sym)
  end
  
  def [](key)
    raise "No valid key given." if !key
    raise "No data was loaded on the object? Maybe you are trying to call a deleted object?" if !@data
    
    if @data.key?(key)
      return @data[key]
    elsif @data.key?(key.to_sym)
      return @data[key.to_sym]
    elsif @data.key?(key.to_s)
      return @data[key.to_s]
    end
    
    raise "No such key: #{key.to_s}."
  end
  
  def []=(key, value)
    self.update(key.to_sym => value)
    self.reload
  end
  
  def id
    return @data[@args[:col_id]]
  end
  
  def title
    if @args[:col_title]
      return @data[@args[:col_title].to_sym]
    end
    
    if @data.key?(:title)
      return @data[:title]
    elsif @data.key?(:name)
      return @data[:name]
    end
    
    raise "'col_title' has not been set for the class: '#{self.class.to_s}'."
  end
  
  alias :name :title
  
  def each(&args)
    return @data.each(&args)
  end
  
  def to_hash
    return @data.clone
  end
  
  def esc(str)
    return self.db.escape(str)
  end
  
  def method_missing(*args)
    func_name = args[0].to_s
    if match = func_name.match(/^(\S+)\?$/) and @data.key?(match[1].to_sym)
      if @data[match[1].to_sym] == "1" or @data[match[1].to_sym] == "yes"
        return true
      elsif @data[match[1].to_sym] == "0" or @data[match[1].to_sym] == "no"
        return false
      end
    end
    
    raise sprintf("No such method: %s", func_name)
  end
end