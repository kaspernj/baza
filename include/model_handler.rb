require "#{File.dirname(__FILE__)}/model_handler_sqlhelper.rb"

class Baza::ModelHandler
  attr_reader :args, :events, :data, :ids_cache, :ids_cache_should
  
  def initialize(args)
    require "monitor"
    
    @callbacks = {}
    @args = args
    @args[:col_id] = :id if !@args[:col_id]
    @args[:class_pre] = "class_" if !@args[:class_pre]
    @args[:module] = Kernel if !@args[:module]
    @args[:cache] = :weak if !@args.key?(:cache)
    @objects = {}
    @locks = {}
    @data = {}
    @lock_require = Monitor.new
    
    Knj.gem_require(:Wref, "wref") if @args[:cache] == :weak and !Kernel.const_defined?(:Wref)
    require "#{@args[:array_enumerator_path]}array_enumerator" if @args[:array_enum] and !Kernel.const_defined?(:Array_enumerator)
    
    #Set up various events.
    @events = Knj::Event_handler.new
    @events.add_event(:name => :no_html, :connections_max => 1)
    @events.add_event(:name => :no_name, :connections_max => 1)
    @events.add_event(:name => :no_date, :connections_max => 1)
    @events.add_event(:name => :missing_class, :connections_max => 1)
    @events.add_event(:name => :require_class, :connections_max => 1)
    
    raise "No DB given." if !@args[:db] and !@args[:custom]
    raise "No class path given." if !@args[:class_path] and (@args[:require] or !@args.key?(:require))
    
    if args[:require_all]
      Knj.gem_require(:Php4r, "php4r")
      loads = []
      
      Dir.foreach(@args[:class_path]) do |file|
        next if file == "." or file == ".." or !file.match(/\.rb$/)
        file_parsed = file
        file_parsed.gsub!(@args[:class_pre], "") if @args.key?(:class_pre)
        file_parsed.gsub!(/\.rb$/, "")
        file_parsed = Php4r.ucwords(file_parsed)
        
        loads << file_parsed
        self.requireclass(file_parsed, {:load => false})
      end
      
      loads.each do |load_class|
        self.load_class(load_class)
      end
    end
    
    #Set up ID-caching.
    @ids_cache_should = {}
    
    if @args[:models]
      @ids_cache = {}
      
      @args[:models].each do |classname, classargs|
        @ids_cache_should[classname] = true if classargs[:cache_ids]
        self.cache_ids(classname)
      end
    end
  end
  
  #Caches all IDs for a specific classname.
  def cache_ids(classname)
    classname = classname.to_sym
    return nil if !@ids_cache_should or !@ids_cache_should[classname]
    
    newcache = {}
    @args[:db].q("SELECT `#{@args[:col_id]}` FROM `#{classname}` ORDER BY `#{@args[:col_id]}`") do |data|
      newcache[data[@args[:col_id]].to_i] = true
    end
    
    @ids_cache[classname] = newcache
  end
  
  def init_class(classname)
    classname = classname.to_sym
    return false if @objects.key?(classname)
    
    if @args[:cache] == :weak
      @objects[classname] = Wref_map.new
    else
      @objects[classname] = {}
    end
    
    @locks[classname] = Monitor.new
  end
  
  def uninit_class(classname)
    @objects.delete(classname)
    @locks.delete(classname)
  end
  
  #Returns a cloned version of the @objects variable. Cloned because iteration on it may crash some of the other methods in Ruby 1.9+
  def objects
    objs_cloned = {}
    
    @objects.keys.each do |key|
      objs_cloned[key] = @objects[key].clone
    end
    
    return objs_cloned
  end
  
  #Returns the database-connection used by this instance of Objects.
  def db
    return @args[:db]
  end
  
  #Returns the total count of objects currently held by this instance.
  def count_objects
    count = 0
    @objects.keys.each do |key|
      count += @objects[key].length
    end
    
    return count
  end
  
  #This connects a block to an event. When the event is called the block will be executed.
  def connect(args, &block)
    raise "No object given." if !args["object"]
    raise "No signals given." if !args.key?("signal") and !args.key?("signals")
    args["block"] = block if block_given?
    object = args["object"].to_sym
    
    @callbacks[object] = {} if !@callbacks[object]
    conn_id = @callbacks[object].length.to_s
    @callbacks[object][conn_id] = args
    return conn_id
  end
  
  #Returns true if the given signal is connected to the given object.
  def connected?(args)
    raise "No object given." if !args["object"]
    raise "No signal given." if !args.key?("signal")
    object = args["object"].to_sym
    
    if @callbacks.key?(object)
      @callbacks[object].clone.each do |ckey, callback|
        return true if callback.key?("signal") and callback["signal"].to_s == args["signal"].to_s
        return true if callback.key?("signals") and (callback["signals"].include?(args["signal"].to_s) or callback["signals"].include?(args["signal"].to_sym))
      end
    end
    
    return false
  end
  
  #Unconnects a connect by 'object' and 'conn_id'.
  def unconnect(args)
    raise ArgumentError, "No object given." if !args["object"]
    object = args["object"].to_sym
    raise ArgumentError, "Object doesnt exist: '#{object}'." if !@callbacks.key?(object)
    
    if args["conn_id"]
      conn_ids = [args["conn_id"]]
    elsif args["conn_ids"]
      conn_ids = args["conn_ids"]
    else
      raise ArgumentError, "Could not figure out connection IDs."
    end
    
    conn_ids.each do |conn_id|
      raise Errno::ENOENT, "Conn ID doest exist: '#{conn_id}' (#{args})." if !@callbacks[object].key?(conn_id)
      @callbacks[object].delete(conn_id)
    end
  end
  
  #This method is used to call the connected callbacks for an event.
  def call(args, &block)
    classstr = args["object"].class.classname.to_sym
    
    if @callbacks.key?(classstr)
      @callbacks[classstr].clone.each do |callback_key, callback|
        docall = false
        
        if callback.key?("signal") and args.key?("signal") and callback["signal"].to_s == args["signal"].to_s
          docall = true
        elsif callback["signals"] and args["signal"] and (callback["signals"].include?(args["signal"].to_s) or callback["signals"].include?(args["signal"].to_sym))
          docall = true
        end
        
        next if !docall
        
        if callback["block"]
          callargs = []
          arity = callback["block"].arity
          if arity <= 0
            #do nothing
          elsif arity == 1
            callargs << args["object"]
          else
            raise "Unknown number of arguments: #{arity}"
          end
          
          callback["block"].call(*callargs)
        elsif callback["callback"]
          require "php4r" if !Kernel.const_defined?(:Php4r)
          Php4r.call_user_func(callback["callback"], args)
        else
          raise "No valid callback given."
        end
      end
    end
  end
  
  def requireclass(classname, args = {})
    classname = classname.to_sym
    return false if @objects.key?(classname)
    
    @lock_require.synchronize do
      #Maybe the classname got required meanwhile the synchronized wait - check again.
      return false if @objects.key?(classname)
      
      if @events.connected?(:require_class)
        @events.call(:require_class, {
          :class => classname
        })
      else
        doreq = false
        
        if args[:require]
          doreq = true
        elsif args.key?(:require) and !args[:require]
          doreq = false
        elsif @args[:require] or !@args.key?(:require)
          doreq = true
        end
        
        if doreq
          filename = "#{@args[:class_path]}/#{@args[:class_pre]}#{classname.to_s.gsub(/(.)([A-Z])/,'\1_\2').downcase}.rb"
          filename_req = "#{@args[:class_path]}/#{@args[:class_pre]}#{classname.to_s.gsub(/(.)([A-Z])/,'\1_\2').downcase}"
          raise "Class file could not be found: #{filename}." if !File.exists?(filename)
          require filename_req
        end
      end
      
      if args[:class]
        classob = args[:class]
      else
        begin
          classob = @args[:module].const_get(classname)
        rescue NameError => e
          if @events.connected?(:missing_class)
            @events.call(:missing_class, {
              :class => classname
            })
            classob = @args[:module].const_get(classname)
          else
            raise e
          end
        end
      end
      
      if (classob.respond_to?(:load_columns) or classob.respond_to?(:datarow_init)) and (!args.key?(:load) or args[:load])
        self.load_class(classname, args)
      end
      
      self.init_class(classname)
    end
  end
  
  #Loads a Datarow-class by calling various static methods.
  def load_class(classname, args = {})
    if args[:class]
      classob = args[:class]
    else
      classob = @args[:module].const_get(classname)
    end
    
    pass_arg = Knj::Hash_methods.new(:ob => self, :db => @args[:db])
    classob.load_columns(pass_arg) if classob.respond_to?(:load_columns)
    classob.datarow_init(pass_arg) if classob.respond_to?(:datarow_init)
  end
  
  #Returns the instance of classname, but only if it already exists.
  def get_if_cached(classname, id)
    classname = classname.to_sym
    id = id.to_i
    
    if wref_map = @objects[classname] and obj = wref_map.get!(id)
      return obj
    end
    
    return nil
  end
  
  #Returns true if a row of the given classname and the ID exists. Will use ID-cache if set in arguments and spawned otherwise it will do an actual lookup.
  #===Examples
  # print "User 5 exists." if ob.exists?(:User, 5)
  def exists?(classname, id)
    #Make sure the given data are in the correct types.
    classname = classname.to_sym
    id = id.to_i
    
    #Check if ID-cache is enabled for that classname. Avoid SQL-lookup by using that.
    if @ids_cache_should.key?(classname)
      if @ids_cache[classname].key?(id)
        return true
      else
        return false
      end
    end
    
    #If the object currently exists in cache, we dont have to do a lookup either.
    return true if @objects.key?(classname) and obj = @objects[classname].get!(id) and !obj.deleted?
    
    #Okay - no other options than to actually do a real lookup.
    begin
      table = @args[:module].const_get(classname).table
      row = @args[:db].single(table, {@args[:col_id] => id})
      
      if row
        return true
      else
        return false
      end
    rescue Errno::ENOENT
      return false
    end
  end
  
  #Gets an object from the ID or the full data-hash in the database.
  #===Examples
  # inst = ob.get(:User, 5)
  def get(classname, data, args = nil)
    classname = classname.to_sym
    
    if data.is_a?(Integer) or data.is_a?(String) or data.is_a?(Fixnum)
      id = data.to_i
    elsif data.is_a?(Hash) and data.key?(@args[:col_id].to_sym)
      id = data[@args[:col_id].to_sym].to_i
    elsif data.is_a?(Hash) and data.key?(@args[:col_id].to_s)
      id = data[@args[:col_id].to_s].to_i
    elsif
      raise ArgumentError, "Unknown data for class '#{classname}': '#{data.class.to_s}' (#{data})."
    end
    
    if @objects.key?(classname)
      case @args[:cache]
        when :weak
          if obj = @objects[classname].get!(id) and obj.id.to_i == id
            return obj
          end
        else
          return @objects[classname][id] if @objects[classname].key?(id)
      end
    end
    
    self.requireclass(classname) if !@objects.key?(classname)
    
    @locks[classname].synchronize do
      #Maybe the object got spawned while we waited for the lock? If so we shouldnt spawn another instance.
      if @args[:cache] == :weak and obj = @objects[classname].get!(id) and obj.id.to_i == id
        return obj
      end
      
      #Spawn object.
      obj = @args[:module].const_get(classname).new(data, args)
      
      #Save object in cache.
      case @args[:cache]
        when :none
          return obj
        else
          @objects[classname][id] = obj
          return obj
      end
    end
    
    raise "Unexpected run?"
  end
  
  #Same as normal get but returns false if not found instead of raising error.
  def get!(*args, &block)
    begin
      return self.get(*args, &block)
    rescue Errno::ENOENT
      return false
    end
  end
  
  def object_finalizer(id)
    classname = @objects_idclass[id]
    if classname
      @objects[classname].delete(id)
      @objects_idclass.delete(id)
    end
  end
  
  #Returns the first object found from the given arguments. Also automatically limits the results to 1.
  def get_by(classname, args = {})
    classname = classname.to_sym
    self.requireclass(classname)
    classob = @args[:module].const_get(classname)
    
    raise "list-function has not been implemented for '#{classname}'." if !classob.respond_to?(:list)
    
    args["limit"] = 1
    self.list(classname, args) do |obj|
      return obj
    end
    
    return false
  end
  
  #Searches for an object with the given data. If not found it creates it. Returns the found or created object in the end.
  def get_or_add(classname, data, args = nil)
    obj = self.get_by(classname, data)
    obj = self.add(classname, data) if !obj
    return obj
  end
  
  def get_try(obj, col_name, obj_name = nil)
    if !obj_name
      if match = col_name.to_s.match(/^(.+)_id$/)
        obj_name = Php4r.ucwords(match[1]).to_sym
      else
        raise "Could not figure out objectname for: #{col_name}."
      end
    end
    
    id_data = obj[col_name].to_i
    return false if id_data.to_i <= 0
    
    begin
      return self.get(obj_name, id_data)
    rescue Errno::ENOENT
      return false
    end
  end
  
  #Returns an array-list of objects. If given a block the block will be called for each element and memory will be spared if running weak-link-mode.
  #===Examples
  # ob.list(:User) do |user|
  #   print "Username: #{user.name}\n"
  # end
  def list(classname, args = {}, &block)
    args = {} if args == nil
    classname = classname.to_sym
    self.requireclass(classname)
    classob = @args[:module].const_get(classname)
    
    raise "list-function has not been implemented for '#{classname}'." if !classob.respond_to?("list")
    ret = classob.list(Knj::Hash_methods.new(:args => args, :ob => self, :db => @args[:db]), &block)
    
    #If 'ret' is an array and a block is given then the list-method didnt return blocks. We emulate it instead with the following code.
    if block and ret.is_a?(Array)
      ret.each do |obj|
        block.call(obj)
      end
      return nil
    elsif block and ret != nil
      raise "Return should return nil because of block but didnt. It wasnt an array either..."
    elsif block
      return nil
    else
      return ret
    end
  end
  
  #Yields every object that is missing certain required objects (based on 'has_many' required-argument).
  def list_invalid_required(args, &block)
    enum = Enumerator.new do |yielder|
      classname = args[:class]
      classob = @args[:module].const_get(classname)
      required_data = classob.required_data
      
      if required_data and !required_data.empty?
        required_data.each do |req_data|
          self.list(args[:class], :cloned_ubuf => true) do |obj|
            puts "Checking #{obj.classname}(#{obj.id}) for required #{req_data[:class]}." if args[:debug]
            id = obj[req_data[:col]]
            
            begin
              raise Errno::ENOENT if !id
              obj_req = self.get(req_data[:class], id)
            rescue Errno::ENOENT
              yielder << {:obj => obj, :type => :required, :id => id, :data => req_data}
            end
          end
        end
      end
    end
    
    return Knj.handle_return(:enum => enum, :block => block)
  end
  
  #Returns select-options-HTML for inserting into a HTML-select-element.
  def list_opts(classname, args = {})
    Knj::ArrayExt.hash_sym(args)
    classname = classname.to_sym
    
    if args[:list_args].is_a?(Hash)
      list_args = args[:list_args]
    else
      list_args = {}
    end
    
    html = ""
    
    if args[:addnew] or args[:add]
      html << "<option"
      html << " selected=\"selected\"" if !args[:selected]
      html << " value=\"\">#{_("Add new")}</option>"
    elsif args[:none]
      html << "<option"
      html << " selected=\"selected\"" if !args[:selected]
      html << " value=\"\">#{_("None")}</option>"
    end
    
    self.list(classname, args[:list_args]) do |object|
      html << "<option value=\"#{object.id.html}\""
      
      selected = false
      if args[:selected].is_a?(Array) and args[:selected].index(object) != nil
        selected = true
      elsif args[:selected] and args[:selected].respond_to?("is_knj?") and args[:selected].id.to_s == object.id.to_s
        selected = true
      end
      
      html << " selected=\"selected\"" if selected
      
      obj_methods = object.class.instance_methods(false)
      
      begin
        if obj_methods.index("name") != nil or obj_methods.index(:name) != nil
          objhtml = object.name.html
        elsif obj_methods.index("title") != nil or obj_methods.index(:title) != nil
          objhtml = object.title.html
        elsif object.respond_to?(:data)
          obj_data = object.data
          
          if obj_data.key?(:name)
            objhtml = obj_data[:name]
          elsif obj_data.key?(:title)
            objhtml = obj_data[:title]
          end
        else
          objhtml = ""
        end
        
        raise "Could not figure out which name-method to call?" if !objhtml
        html << ">#{objhtml}</option>"
      rescue => e
        html << ">[#{object.class.name}: #{e.message}]</option>"
      end
    end
    
    return html
  end
  
  #Returns a hash which can be used to generate HTML-select-elements.
  def list_optshash(classname, args = {})
    Knj::ArrayExt.hash_sym(args)
    classname = classname.to_sym
    
    if args[:list_args].is_a?(Hash)
      list_args = args[:list_args]
    else
      list_args = {}
    end
    
    if RUBY_VERSION[0..2] == 1.8 and Php4r.class_exists("Dictionary")
      list = Dictionary.new
    else
      list = {}
    end
    
    if args[:addnew] or args[:add]
      list["0"] = _("Add new")
    elsif args[:choose]
      list["0"] = _("Choose") + ":"
    elsif args[:all]
      list["0"] = _("All")
    elsif args[:none]
      list["0"] = _("None")
    end
    
    self.list(classname, args[:list_args]) do |object|
      if object.respond_to?(:name)
        list[object.id] = object.name
      elsif object.respond_to?(:title)
        list[object.id] = object.title
      else
        raise "Object of class '#{object.class.name}' doesnt support 'name' or 'title."
      end
    end
    
    return list
  end
  
  #Returns a list of a specific object by running specific SQL against the database.
  def list_bysql(classname, sql, args = nil, &block)
    classname = classname.to_sym
    ret = [] if !block
    qargs = nil
    
    if args
      args.each do |key, val|
        case key
          when :cloned_ubuf
            qargs = {:cloned_ubuf => true}
          else
            raise "Invalid key: '#{key}'."
        end
      end
    end
    
    if @args[:array_enum]
      enum = Enumerator.new do |yielder|
        @args[:db].q(sql, qargs) do |d_obs|
          yielder << self.get(classname, d_obs)
        end
      end
      
      if block
        enum.each(&block)
        return nil
      else
        return Array_enumerator.new(enum)
      end
    else
      @args[:db].q(sql, qargs) do |d_obs|
        if block
          block.call(self.get(classname, d_obs))
        else
          ret << self.get(classname, d_obs)
        end
      end
      
      if !block
        return ret
      else
        return nil
      end
    end
  end
  
  #Add a new object to the database and to the cache.
  #===Examples
  # obj = ob.add(:User, {:username => "User 1"})
  def add(classname, data = {}, args = nil)
    raise "data-variable was not a hash: '#{data.class.name}'." if !data.is_a?(Hash)
    classname = classname.to_sym
    self.requireclass(classname)
    
    if @args[:custom]
      classobj = @args[:module].const_get(classname)
      retob = classobj.add(Knj::Hash_methods.new(
        :ob => self,
        :data => data
      ))
    else
      classobj = @args[:module].const_get(classname)
      
      #Run the class 'add'-method to check various data.
      classobj.add(Knj::Hash_methods.new(:ob => self, :db => @args[:db], :data => data)) if classobj.respond_to?(:add)
      
      #Check if various required data is given. If not then raise an error telling about it.
      required_data = classobj.required_data
      required_data.each do |req_data|
        raise "No '#{req_data[:class]}' given by the data '#{req_data[:col]}'." if !data.key?(req_data[:col])
        raise "The '#{req_data[:class]}' by ID '#{data[req_data[:col]]}' could not be found with the data '#{req_data[:col]}'." if !self.exists?(req_data[:class], data[req_data[:col]])
      end
      
      #If 'skip_ret' is given, then the ID wont be looked up and the object wont be spawned. Be aware the connected events wont be executed either. In return it will go a lot faster.
      if args and args[:skip_ret] and !@ids_cache_should.key?(classname)
        ins_args = nil
      else
        ins_args = {:return_id => true}
      end
      
      #Insert and (maybe?) get ID.
      ins_id = @args[:db].insert(classobj.table, data, ins_args).to_i
      
      #Add ID to ID-cache if ID-cache is active for that classname.
      @ids_cache[classname][ins_id] = true if ins_id != 0 and @ids_cache_should.key?(classname)
      
      #Skip the rest if we are told not to return result.
      return nil if args and args[:skip_ret]
      
      #Spawn the object.
      retob = self.get(classname, ins_id, {:skip_reload => true})
    end
    
    self.call("object" => retob, "signal" => "add")
    retob.send(:add_after, {}) if retob.respond_to?(:add_after)
    
    return retob
  end
  
  #Adds several objects to the database at once. This is faster than adding every single object by itself, since this will do multi-inserts if supported by the database.
  #===Examples
  # ob.adds(:User, [{:username => "User 1"}, {:username => "User 2"})
  def adds(classname, datas)
    datas.each do |data|
      @args[:module].const_get(classname).add(*args)
      self.call("object" => retob, "signal" => "add")
    end
    
    self.cache_ids(classname)
  end
  
  #Calls a static method on a class. Passes the d-variable which contains the Objects-object, database-reference and more...
  def static(class_name, method_name, *args, &block)
    class_name = class_name
    method_name = method_name
    
    self.requireclass(class_name)
    class_obj = @args[:module].const_get(class_name)
    
    #Sometimes this raises the exception but actually responds to the class? Therefore commented out. - knj
    #raise "The class '#{class_obj.name}' has no such method: '#{method_name}' (#{class_obj.methods.sort.join(", ")})." if !class_obj.respond_to?(method_name)
    
    pass_args = [Knj::Hash_methods.new(:ob => self, :db => self.db)]
    
    args.each do |arg|
      pass_args << arg
    end
    
    class_obj.send(method_name, *pass_args, &block)
  end
  
  #Unset object. Do this if you are sure, that there are no more references left. This will be done automatically when deleting it.
  def unset(object)
    if object.is_a?(Array)
      object.each do |obj|
        unset(obj)
      end
      return nil
    end
    
    classname = object.class.name
    
    if @args[:module]
      classname = classname.gsub(@args[:module].name + "::", "")
    end
    
    classname = classname.to_sym
    @objects[classname].delete(object.id.to_i)
  end
  
  def unset_class(classname)
    if classname.is_a?(Array)
      classname.each do |classn|
        self.unset_class(classn)
      end
      
      return false
    end
    
    classname = classname.to_sym
    
    return false if !@objects.key?(classname)
    @objects.delete(classname)
  end
  
  #Delete an object. Both from the database and from the cache.
  #===Examples
  # user = ob.get(:User, 1)
  # ob.delete(user)
  def delete(object, args = nil)
    #Return false if the object has already been deleted.
    return false if object.deleted?
    classname = object.class.classname.to_sym
    
    self.call("object" => object, "signal" => "delete_before")
    self.unset(object)
    obj_id = object.id
    object.delete if object.respond_to?(:delete)
    
    #If autodelete is set by 'has_many'-method, go through it and delete the various objects first.
    if autodelete_data = object.class.autodelete_data
      autodelete_data.each do |adel_data|
        self.list(adel_data[:classname], {adel_data[:colname].to_s => object.id}) do |obj_del|
          self.delete(obj_del, args)
        end
      end
    end
    
    #If depend is set by 'has_many'-method, check if any objects exists and raise error if so.
    if dep_datas = object.class.depending_data
      dep_datas.each do |dep_data|
        if obj = self.get_by(dep_data[:classname], {dep_data[:colname].to_s => object.id})
          raise "Cannot delete <#{object.class.name}:#{object.id}> because <#{obj.class.name}:#{obj.id}> depends on it."
        end
      end
    end
    
    #If autozero is set by 'has_many'-method, check if any objects exists and set the ID to zero.
    if autozero_datas = object.class.autozero_data
      autozero_datas.each do |zero_data|
        self.list(zero_data[:classname], {zero_data[:colname].to_s => object.id}) do |obj_zero|
          obj_zero[zero_data[:colname].to_sym] = 0
        end
      end
    end
    
    #Delete any translations that has been set on the object by 'has_translation'-method.
    if object.class.translations
      begin
        _hb.trans_del(object)
      rescue NameError
        _kas.trans_del(object)
      end
    end
    
    
    #If a buffer is given in arguments, then use that to delete the object.
    if args and buffer = args[:db_buffer]
      buffer.delete(object.table, {:id => obj_id})
    else
      @args[:db].delete(object.table, {:id => obj_id})
    end
    
    @ids_cache[classname].delete(obj_id.to_i) if @ids_cache_should.key?(classname)
    self.call("object" => object, "signal" => "delete")
    object.destroy
    return nil
  end
  
  #Deletes several objects as one. If running datarow-mode it checks all objects before it starts to actually delete them. Its faster than deleting every single object by itself...
  def deletes(objs)
    tables = {}
    
    begin
      objs.each do |obj|
        next if obj.deleted?
        tablen = obj.table
        
        if !tables.key?(tablen)
          tables[tablen] = []
        end
        
        tables[tablen] << obj.id
        obj.delete if obj.respond_to?(:delete)
        
        #Remove from ID-cache.
        classname = obj.class.classname.to_sym
        @ids_cache[classname].delete(obj.id.to_i) if @ids_cache_should.key?(classname)
        
        #Unset any data on the object, so it seems deleted.
        obj.destroy
      end
    ensure
      #An exception may occur, and we should make sure, that objects that has gotten 'delete' called also are deleted from their tables.
      tables.each do |table, ids|
        ids.each_slice(1000) do |ids_slice|
          @args[:db].delete(table, {:id => ids_slice})
        end
      end
    end
  end
  
  #Deletes all objects with the given IDs 500 at a time to prevent memory exhaustion or timeout.
  #===Examples
  #  ob.delete_ids(:class => :Person, :ids => [1, 3, 5, 6, 7, 8, 9])
  def delete_ids(args)
    while !args[:ids].empty? and ids = args[:ids].shift(500)
      objs = self.list(args[:class], "id" => ids)
      self.deletes(objs)
    end
    
    return nil
  end
  
  #Try to clean up objects by unsetting everything, start the garbagecollector, get all the remaining objects via ObjectSpace and set them again. Some (if not all) should be cleaned up and our cache should still be safe... dirty but works.
  def clean(classn)
    if classn.is_a?(Array)
      classn.each do |realclassn|
        self.clean(realclassn)
      end
      
      return nil
    end
    
    if @args[:cache] == :weak
      @objects[classn].clean
    elsif @args[:cache] == :none
      return false
    else
      return false if !@objects.key?(classn)
      @objects[classn] = {}
      GC.start
      
      @objects.keys.each do |classn|
        data = @objects[classn]
        classobj = @args[:module].const_get(classn)
        ObjectSpace.each_object(classobj) do |obj|
          begin
            data[obj.id.to_i] = obj
          rescue => e
            if e.message == "No data on object."
              #Object has been unset - skip it.
              next
            end
            
            raise e
          end
        end
      end
    end
  end
  
  #Erases the whole cache and regenerates it from ObjectSpace if not running weak-link-caching. If running weaklink-caching then it will only removes the dead links.
  def clean_all
    self.clean(@objects.keys)
  end
  
  def classes_loaded
    return @objects.keys
  end
end

require "#{$knjpath}objects/objects_sqlhelper"