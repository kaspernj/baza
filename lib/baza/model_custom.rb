require "#{$knjpath}event_handler"

class Baza::ModelCustom
  #Used to determine if this is a knj-datarow-object.
  def is_knj?
    return true
  end
  
  #Initializes variables on the class from objects.
  def self.datarow_init(d)
    @@ob = d.ob
    @@db = d.db
  end
  
  def self.has_one(arr)
    arr.each do |val|
      methodname = nil
      colname = nil
      classname = nil
      
      if val.is_a?(Symbol)
        classname = val
        methodname = val.to_s.downcase.to_sym
        colname = "#{val.to_s.downcase}_id".to_sym
      elsif val.is_a?(Array)
        classname, colname, methodname = *val
      elsif val.is_a?(Hash)
        classname, colname, methodname = val[:class], val[:col], val[:method]
      else
        raise "Unknown argument-type: '#{arr.class.name}'."
      end
      
      methodname = classname.to_s.downcase if !methodname
      colname = "#{classname.to_s.downcase}_id".to_sym if !colname
      
      define_method(methodname) do
        return @@ob.get_try(self, colname, classname)
      end
      
      methodname_html = "#{methodname.to_s}_html".to_sym
      define_method(methodname_html) do |*args|
        obj = self.send(methodname)
        return @@ob.events.call(:no_html, classname) if !obj
        
        raise "Class '#{classname}' does not have a 'html'-method." if !obj.respond_to?(:html)
        return obj.html(*args)
      end
    end
  end
  
  def self.events
    if !@events
      @events = Knj::Event_handler.new
      @events.add_event(:name => :add, :connections_max => 1)
      @events.add_event(:name => :update, :connections_max => 1)
      @events.add_event(:name => :data_from_id, :connections_max => 1)
      @events.add_event(:name => :delete, :connections_max => 1)
    end
    
    return @events
  end
  
  def self.classname
    self.name.split("::").last
  end
  
  def self.add(d)
    return @events.call(:add, d)
  end
  
  def self.table
    return self.name.split("::").last
  end
  
  def deleted?
    return true if !@data
    return false
  end
  
  def table
    return self.class.table
  end
  
  def initialize(data, args)
    if data.is_a?(Hash)
      @data = Knj::ArrayExt.hash_sym(data)
      @id = self.id
    else
      @id = data
      self.reload
    end
  end
  
  def reload
    raise "No 'data_from_id'-event connected to class." if !self.class.events.connected?(:data_from_id)
    data = self.class.events.call(:data_from_id, Knj::Hash_methods.new(:id => @id))
    raise "No data was received from the event: 'data_from_id'." if !data
    raise "Data expected to be a hash but wasnt: '#{data.class.name}'." if !data.is_a?(Hash)
    @data = Knj::ArrayExt.hash_sym(data)
  end
  
  def update(data)
    ret = self.class.events.call(:update, Knj::Hash_methods.new(:object => self, :data => data))
    self.reload
    return ret
  end
  
  #Returns a key from the hash that this object is holding or raises an error if it doesnt exist.
  def [](key)
    raise "No data spawned on object." if !@data
    raise "No such key: '#{key}'. Available keys are: '#{@data.keys.sort.join(", ")}'." if !@data.key?(key)
    return @data[key]
  end
  
  #Returns the ID of the object.
  def id
    return self[:id]
  end
  
  #Returns the name of the object, which can be taken from various data or various defined methods.
  def name
    if @data.key?(:title)
      return @data[:title]
    elsif @data.key?(:name)
      return @data[:name]
    end
    
    obj_methods = self.class.instance_methods(false)
    [:name, :title].each do |method_name|
      return self.method(method_name).call if obj_methods.index(method_name)
    end
    
    raise "Couldnt figure out the title/name of the object on class #{self.class.name}."
  end
  
  alias :title :name
  
  def delete
    self.class.events.call(:delete, Knj::Hash_methods.new(:object => self))
  end
  
  def destroy
    @data = nil
  end
  
  def each(&args)
    return @data.each(&args)
  end
  
  def to_hash
    return @data.clone
  end
end