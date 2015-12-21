# This class helps create models in a framework with Baza::Db and Baza::ModelHandler.
#===Examples
#  db = Baza::Db.new(type: :sqlite3, path: "somepath.sqlite3")
#  ob = Baza::ModelHandler.new(db: db, datarow: true, path: "path_of_model_class_files")
#  user = ob.get(:User, 1) #=> <Models::User> that extends <Baza::Datarow>
class Baza::Model
  @@refs = {}

  # Returns the Baza::ModelHandler which handels this model.
  def ob
    self.class.ob
  end

  # Returns the Baza::Db which handels this model.
  def db
    self.class.db
  end

  # Returns the 'Baza::ModelHandler'-object that handels this class.
  class << self
    attr_reader :ob
  end

  # Returns the 'Baza::Db'-object that handels this class.
  class << self
    attr_reader :db
  end

  # This is used by 'Baza::ModelHandler' to find out what data is required for this class. Returns the array that tells about required data.
  #===Examples
  # When adding a new user, this can fail if the ':group_id' is not given, or the ':group_id' doesnt refer to a valid group-row in the db.
  #  class Models::User < Baza::Datarow
  #    has_one [
  #      {class: :Group, col: :group_id, method: :group, required: true}
  #    ]
  #  end
  def self.required_data
    @required_data = [] unless @required_data
    @required_data
  end

  # This is used by 'Baza::ModelHandler' to find out what other objects this class depends on. Returns the array that tells about depending data.
  #===Examples
  # This will tell Baza::ModelHandler that files depends on users. It can prevent the user from being deleted, if any files depend on it.
  #  class Models::User < Baza::Datarow
  #    has_many [
  #      {class: :File, col: :user_id, method: :files, depends: true}
  #    ]
  #  end
  class << self
    attr_reader :depending_data
  end

  # Returns true if this class has been initialized.
  def self.initialized?
    false unless @columns_sqlhelper_args
    true
  end

  # This is used by 'Baza::ModelHandler' to find out which other objects should be deleted when an object of this class is deleted automatically. Returns the array that tells about autodelete data.
  #===Examples
  # This will trigger Baza::ModelHandler to automatically delete all the users pictures, when deleting the current user.
  #  class Models::User < Baza::Datarow
  #    has_many [
  #      {class: :Picture, col: :user_id, method: :pictures, autodelete: true}
  #    ]
  #  end
  class << self
    attr_reader :autodelete_data
  end

  # Returns the autozero-data (if any).
  class << self
    attr_reader :autozero_data
  end

  class << self
    attr_accessor :classname
  end

  # This helps various parts of the framework determine if this is a datarow class without requiring it.
  #===Examples
  #  print "This is a knj-object." if obj.respond_to?("is_knj?")
  def knj?
    true
  end

  # This tests if a certain string is a date-null-stamp.
  #===Examples
  #  time_str = dbrow[:date]
  #  print "No valid date on the row." if Baza::Datarow.is_nullstamp?(time_str)
  def self.nullstamp?(stamp)
    return true if !stamp || stamp == "0000-00-00 00:00:00" || stamp == "0000-00-00"
    false
  end

  # This is used to define datarows that this object can have a lot of.
  #===Examples
  # This will define the method "pictures" on 'Models::User' that will return all pictures for the users and take possible Objects-sql-arguments. It will also enabling joining pictures when doing Objects-sql-lookups.
  #  class Models::User < Baza::Datarow
  #    has_many [
  #      [:Picture, :user_id, :pictures],
  #      {class: :File, col: :user_id, method: :files}
  #    ]
  #  end
  def self.has_many(arr)
    arr.each do |val|
      if val.is_a?(Array)
        classname, colname, methodname = *val
      elsif val.is_a?(Hash)
        classname = nil
        colname = nil
        methodname = nil

        val.each do |hkey, hval|
          case hkey
          when :class
            classname = hval
          when :col
            colname = hval
          when :method
            methodname = hval
          when :depends, :autodelete, :autozero, :where
            # Ignore
          else
            raise "Invalid key for 'has_many': '#{hkey}'."
          end
        end

        colname = "#{name.to_s.split("::").last.to_s.downcase}_id".to_sym if colname.to_s.empty?

        if val[:depends]
          @depending_data = [] unless @depending_data
          @depending_data << {
            colname: colname,
            classname: classname
          }
        end

        if val[:autodelete]
          @autodelete_data = [] unless @autodelete_data
          @autodelete_data << {
            colname: colname,
            classname: classname
          }
        end

        if val[:autozero]
          @autozero_data = [] unless @autozero_data
          @autozero_data << {
            colname: colname,
            classname: classname
          }
        end
      else
        raise "Unknown argument: '#{val.class.name}'."
      end

      raise "No classname given." unless classname
      methodname = "#{StringCases.camel_to_snake(classname)}s".to_sym unless methodname
      raise "No column was given for '#{name}' regarding has-many-class: '#{classname}'." unless colname

      if val.is_a?(Hash) && val.key?(:where)
        where_args = val[:where]
      else
        where_args = nil
      end

      define_many_methods(classname, methodname, colname, where_args)

      joined_tables(
        classname => {
          where: {
            colname.to_s => {type: :col, name: :id}
          }
        }
      )
    end
  end

  # This define is this object has one element of another datarow-class. It define various methods and joins based on that.
  #===Examples
  #  class Models::User < Baza::Datarow
  #    has_one [
  #      #Defines the method 'group', which returns a 'Group'-object by the column 'group_id'.
  #      :Group,
  #
  #      #Defines the method 'type', which returns a 'Type'-object by the column 'type_id'.
  #      {class: :Type, col: :type_id, method: :type}
  #    ]
  #  end
  def self.has_one(arr)
    arr = [arr] if arr.is_a?(Symbol)

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
        classname = nil
        colname = nil
        methodname = nil

        val.each do |hkey, hval|
          case hkey
          when :class
            classname = hval
          when :col
            colname = hval
          when :method
            methodname = hval
          when :required
            # Ignore
          else
            raise "Invalid key for class '#{name}' functionality 'has_many': '#{hkey}'."
          end
        end

        if val[:required]
          colname = "#{classname.to_s.downcase}_id".to_sym unless colname
          required_data << {
            col: colname,
            class: classname
          }
        end
      else
        raise "Unknown argument-type: '#{arr.class.name}'."
      end

      methodname = StringCases.camel_to_snake(classname) unless methodname
      colname = "#{classname.to_s.downcase}_id".to_sym unless colname
      define_one_methods(classname, methodname, colname)

      joined_tables(
        classname => {
          where: {
            "id" => {type: :col, name: colname}
          }
        }
      )
    end
  end

  # This method initializes joins, sets methods to update translations and makes the translations automatically be deleted when the object is deleted.
  #===Examples
  #  class Models::Article < Baza::Datarow
  #    #Defines methods such as: 'title', 'title=', 'content', 'content='. When used with Knjappserver these methods will change what they return and set based on the current language of the session.
  #    has_translation [:title, :content]
  #  end
  #
  #  article = ob.get(:Article, 1)
  #  print "The title in the current language is: '#{article.title}'."
  #
  #  article.title = 'Title in english if the language is english'
  def self.has_translation(arr)
    @translations = [] unless @translations

    arr.each do |val|
      @translations << val

      val_dc = val.to_s.downcase
      table_name = "Translation_#{val_dc}".to_sym

      joined_tables(
        table_name => {
          where: {
            "object_class" => name,
            "object_id" => {type: :col, name: :id},
            "key" => val.to_s,
            "locale" => proc { |_d| _session[:locale] }
          },
          parent_table: :Translation,
          datarow: Knj::Translations::Translation,
          ob: @ob
        }
      )

      define_translation_methods(val: val, val_dc: val_dc)
    end
  end

  # This returns all translations for this datarow-class.
  class << self
    attr_reader :translations
  end

  # Returns data about joined tables for this class.
  def self.joined_tables(hash)
    @columns_joined_tables = {} unless @columns_joined_tables
    @columns_joined_tables.merge!(hash)
  end

  # Returns various data for the objects-sql-helper. This can be used to view various informations about the columns and more.
  def self.columns_sqlhelper_args
    raise "No SQLHelper arguments has been spawned yet." unless @columns_sqlhelper_args
    @columns_sqlhelper_args
  end

  # Called by Baza::ModelHandler to initialize the model and load column-data on-the-fly.
  def self.load_columns(d)
    @ob = d.ob
    @db = d.db

    @classname = name.split("::").last.to_sym unless @classname
    @table = @classname unless @table
    @mutex = Monitor.new unless @mutex

    # Cache these to avoid method-lookups.
    @sep_col = @db.sep_col
    @sep_table = @db.sep_table
    @table_str = "#{@sep_table}#{@db.esc_table(@table)}#{@sep_table}"

    @mutex.synchronize do
      inst_methods = instance_methods(false)

      sqlhelper_args = {
        db: @db,
        table: @table,
        cols_bools: [],
        cols_date: [],
        cols_dbrows: [],
        cols_num: [],
        cols_str: [],
        cols: {}
      }

      sqlhelper_args[:table] = @table

      @db.tables[table].columns do |col_obj|
        col_name = col_obj.name.to_s
        col_name_sym = col_name.to_sym
        col_type = col_obj.type
        col_type = :int if col_type == :bigint || col_type == :tinyint || col_type == :mediumint || col_type == :smallint
        sqlhelper_args[:cols][col_name] = true

        define_bool_methods(inst_methods, col_name)

        if col_type == :enum && col_obj.maxlength == "'0','1'"
          sqlhelper_args[:cols_bools] << col_name
        elsif col_type == :int && col_name.slice(-3, 3) == "_id"
          sqlhelper_args[:cols_dbrows] << col_name
        elsif col_type == :int || col_type == :decimal
          sqlhelper_args[:cols_num] << col_name
        elsif col_type == :varchar || col_type == :text || col_type == :enum
          sqlhelper_args[:cols_str] << col_name
        elsif col_type == :date || col_type == :datetime
          sqlhelper_args[:cols_date] << col_name
          define_date_methods(inst_methods, col_name_sym)
        end

        if col_type == :int || col_type == :decimal
          define_numeric_methods(inst_methods, col_name_sym)
        end

        if col_type == :int || col_type == :varchar
          define_text_methods(inst_methods, col_name_sym)
        end

        define_time_methods(inst_methods, col_name_sym) if col_type == :time
      end

      if @columns_joined_tables
        @columns_joined_tables.each do |table_name, table_data|
          table_data[:where].each do |_key, val|
            val[:table] = @table if val.is_a?(Hash) && !val.key?(:table) && val[:type].to_sym == :col
          end

          table_data[:datarow] = @ob.args[:module].const_get(table_name.to_sym) unless table_data.key?(:datarow)
        end

        sqlhelper_args[:joined_tables] = @columns_joined_tables
      end

      @columns_sqlhelper_args = sqlhelper_args
    end

    init_class(d) if self.respond_to?(:init_class)
  end

  # This method helps returning objects and supports various arguments. It should be called by Object#list.
  #===Examples
  #  ob.list(:User, {"username_lower" => "john doe"}) do |user|
  #    print user.id
  #  end
  #
  #  array = ob.list(:User, {"id" => 1})
  #  print array.length
  def self.list(d, &block)
    args = d.args

    if args["count"]
      count = true
      args.delete("count")
      sql = "SELECT COUNT(#{@table_str}.#{@sep_col}id#{@sep_col}) AS count"
    elsif args["select_col_as_array"]
      select_col_as_array = true
      sql = "SELECT #{@table_str}.#{@sep_col}#{args["select_col_as_array"]}#{@sep_col} AS id"
      args.delete("select_col_as_array")
    else
      sql = "SELECT #{@table_str}.*"
    end

    qargs = nil
    ret = list_helper(d)

    sql << " FROM #{@table_str}"
    sql << ret[:sql_joins]
    sql << " WHERE 1=1"
    sql << ret[:sql_where]

    args.each do |key, _val|
      case key
      when "return_sql"
        # Ignore
      when :cloned_ubuf
        qargs = {cloned_ubuf: true}
      else
        raise "Invalid key: '#{key}' for '#{name}'. Valid keys are: '#{@columns_sqlhelper_args[:cols].keys.sort}'. Date-keys: '#{@columns_sqlhelper_args[:cols_date]}'."
      end
    end

    # The count will bug if there is a group-by-statement.
    grp_shown = false
    if !count && !ret[:sql_groupby]
      sql << " GROUP BY #{@table_str}.#{@sep_col}id#{@sep_col}"
      grp_shown = true
    end

    if ret[:sql_groupby]
      if !grp_shown
        sql << " GROUP BY"
      else
        sql << ", "
      end

      sql << ret[:sql_groupby]
    end

    sql << ret[:sql_order]
    sql << ret[:sql_limit]

    return sql.to_s if args["return_sql"]

    if select_col_as_array
      enum = Enumerator.new do |yielder|
        @db.q(sql, qargs) do |data|
          yielder << data[:id]
        end
      end

      if block
        enum.each(&block)
        return nil
      elsif @ob.args[:array_enum]
        return ArrayEnumerator.new(enum)
      else
        return enum.to_a
      end
    elsif count
      ret = @db.query(sql).fetch
      return ret[:count].to_i if ret
      return 0
    end

    @ob.list_bysql(classname, sql, qargs, &block)
  end

  # Helps call 'sqlhelper' on Baza::ModelHandler to generate SQL-strings.
  def self.list_helper(d)
    load_columns(d) unless @columns_sqlhelper_args
    @columns_sqlhelper_args[:table] = @table
    @ob.sqlhelper(d.args, @columns_sqlhelper_args)
  end

  # Returns the table-name that should be used for this datarow.
  #===Examples
  #  db.query("SELECT * FROM `#{Models::User.table}` WHERE username = 'John Doe'") do |data|
  #    print data[:id]
  #  end
  class << self
    attr_reader :table
  end

  # This can be used to manually set the table-name. Useful when meta-programming classes that extends the datarow-class.
  #===Examples
  #  Models::User.table = "prefix_User"
  def self.table=(newtable)
    @table = newtable
    @columns_sqlhelper_args[:table] = @table if @columns_sqlhelper_args.is_a?(Hash)
  end

  # Returns the class-name but without having to call the class-table-method. To make code look shorter.
  #===Examples
  #  user = ob.get_by(:User, {username: 'John Doe'})
  #  db.query("SELECT * FROM `#{user.table}` WHERE username = 'John Doe'") do |data|
  #    print data[:id]
  #  end
  def table
    self.class.table
  end

  # Initializes the object. This should be called from 'Baza::ModelHandler' and not manually.
  #===Examples
  #  user = ob.get(:User, 3)
  def initialize(data, args = nil)
    if data.is_a?(Hash) && data.key?(:id)
      @data = data
      @id = @data[:id].to_i
    elsif data
      @id = data.to_i

      classname = self.class.classname.to_sym
      if self.class.ob.ids_cache_should.key?(classname)
        # ID caching is enabled for this model - dont reload until first use.
        raise Errno::ENOENT, "ID was not found in cache: '#{id}'." unless self.class.ob.ids_cache[classname].key?(@id)
        @should_reload = true
      else
        # ID caching is not enabled - reload now to check if row exists. Else set 'should_reload'-variable if 'skip_reload' is set.
        if !args || !args[:skip_reload]
          reload
        else
          @should_reload = true
        end
      end
    else
      raise ArgumentError, "Could not figure out the data from '#{data.class.name}'."
    end

    return unless @id.to_i <= 0

    raise "Invalid ID: '#{@id}' from '#{@data}'." if @data
    raise "Invalid ID: '#{@id}'."
  end

  # Reloads the data from the database.
  #===Examples
  #  old_username = user[:username]
  #  user.reload
  #  print "The username changed in the database!" if user[:username] != old_username
  def reload
    @data = self.class.db.single(self.class.table, id: @id)
    raise Errno::ENOENT, "Could not find any data for the object with ID: '#{@id}' in the table '#{self.class.table}'." unless @data
    @should_reload = false
  end

  # Tells the object that it should reloads its data because it has changed. It wont reload before it is required though, which may save you a couple of SQL-calls.
  #===Examples
  #  obj = _ob.get(:User, 5)
  #  obj.should_reload
  def should_reload
    @should_reload = true
    @data = nil
  end

  # Returns the data-hash that contains all the data from the database.
  def data
    reload if @should_reload
    @data
  end

  # Writes/updates new data for the object.
  #===Examples
  #  user.update(username: 'New username', date_changed: Time.now)
  def update(newdata)
    self.class.db.update(self.class.table, newdata, id: @id)
    should_reload
    self.class.ob.call("object" => self, "signal" => "update")
  end

  # Forcefully destroys the object. This is done after deleting it and should not be called manually.
  def destroy
    @id = nil
    @data = nil
    @should_reload = nil
  end

  # Returns true if that key exists on the object.
  #===Examples
  #  print "Looks like the user has a name." if user.key?(:name)
  def key?(key)
    reload if @should_reload
    @data.key?(key.to_sym)
  end
  alias_method :has_key?, :key?

  # Returns true if the object has been deleted.
  #===Examples
  #  print "That user is deleted." if user.deleted?
  def deleted?
    return true if !@data && !@id
    false
  end

  # Returns true if the given object no longer exists in the database. Also destroys the data on the object and sets it to deleted-status, if it no longer exists.
  #===Examples
  # print "That user is deleted." if user.deleted_from_db?
  def deleted_from_db?
    # Try to avoid db-query if object is already deleted.
    return true if self.deleted?

    # Try to reload data. Destroy object and return true if the row is gone from the database.
    begin
      reload
      return false
    rescue Errno::ENOENT
      destroy
      return true
    end
  end

  # Returns a specific data from the object by key.
  #  print "Username: #{user[:username]}\n"
  #  print "ID: #{user[:id]}\n"
  #  print "ID again: #{user.id}\n"
  def [](key)
    raise "Key was not a symbol: '#{key.class.name}'." unless key.is_a?(Symbol)
    return @id if !@data && key == :id && @id
    reload if @should_reload
    raise "No data was loaded on the object? Maybe you are trying to call a deleted object? (#{self.class.classname}(#{@id}), #{@should_reload})" unless @data
    return @data[key] if @data.key?(key)
    raise "No such key: '#{key}' on '#{self.class.name}' (#{@data.keys.join(", ")}) (#{@should_reload})."
  end

  # Writes/updates a keys value on the object.
  #  user = ob.get_by(:User, {"username" => "John Doe"})
  #  user[:username] = 'New username'
  def []=(key, value)
    update(key.to_sym => value)
    should_reload
  end

  # Returns the objects ID.
  def id
    raise Errno::ENOENT, "This object has been deleted." if deleted?
    raise "No ID on object." unless @id
    @id
  end

  # This enable Wref to not return the wrong object.
  def __object_unique_id__
    return 0 if self.deleted?
    id
  end

  # Tries to figure out, and returns, the possible name or title for the object.
  def name
    reload if @should_reload

    if @data.key?(:title)
      return @data[:title]
    elsif @data.key?(:name)
      return @data[:name]
    end

    obj_methods = self.class.instance_methods(false)
    [:name, :title].each do |method_name|
      return method(method_name).call if obj_methods.index(method_name)
    end

    raise "Couldnt figure out the title/name of the object on class #{self.class.name}."
  end

  # Calls the name-method and returns a HTML-escaped value. Also "[no name]" if the name is empty.
  def name_html
    name_str = name.to_s
    name_str = "[no name]" if name_str.empty?
    name_str
  end

  alias_method :title, :name

  # Loops through the data on the object.
  #===Examples
  #  user = ob.get(:User, 1)
  #  user.each do |key, val|
  #    print "#{key}: #{val}\n" #=> username: John Doe
  #  end
  def each(*args, &block)
    reload if @should_reload
    @data.each(*args, &block)
  end

  # Hash-compatible.
  def to_hash
    reload if @should_reload
    @data.clone
  end

  # Returns a default-URL to show the object.
  def url
    cname = self.class.classname.to_s.downcase
    "?show=#{cname}_show&#{cname}_id=#{id}"
  end

  # Returns the URL for editting the object.
  def url_edit
    cname = self.class.classname.to_s.downcase
    "?show=#{cname}_edit&#{cname}_id=#{id}"
  end

  # Returns the HTML for making a link to the object.
  def html(args = nil)
    if args && args[:edit]
      url = url_edit
    else
      url = self.url
    end

    "<a href=\"#{Knj::Web.ahref_parse(url)}\">#{name_html}</a>"
  end

private

  # Various methods to define methods based on the columns for the datarow.
  def self.define_translation_methods(args)
    define_method("#{args[:val_dc]}=") do |newtransval|
      begin
        _hb.trans_set(self, args[:val] => newtransval)
      rescue NameError
        _kas.trans_set(self, args[:val] => newtransval)
      end
    end

    define_method("#{args[:val_dc]}") do
      begin
        return _hb.trans(self, args[:val])
      rescue NameError
        return _kas.trans(self, args[:val])
      end
    end

    define_method("#{args[:val_dc]}_html") do
      begin
        str = _hb.trans(self, args[:val])
      rescue NameError
        str = _kas.trans(self, args[:val])
      end

      return "[no translation for #{args[:val]}]" if str.to_s.strip.empty?

      return str
    end
  end

  # Defines the boolean-methods based on enum-columns.
  def self.define_bool_methods(inst_methods, col_name)
    # Spawns a method on the class which returns true if the data is 1.
    return if inst_methods.include?("#{col_name}?".to_sym)

    define_method("#{col_name}?") do
      return true if self[col_name.to_sym].to_s == "1"
      return false
    end
  end

  # Defines date- and time-columns based on datetime- and date-columns.
  def self.define_date_methods(inst_methods, col_name)
    return if inst_methods.include?("#{col_name}_str".to_sym)

    define_method("#{col_name}_str") do |*method_args|
      if Datet.is_nullstamp?(self[col_name])
        return self.class.ob.events.call(:no_date, self.class.name)
      end

      return Datet.in(self[col_name]).out(*method_args)
    end

    return if inst_methods.include?(col_name)

    define_method(col_name) do |*_method_args|
      return false if Datet.is_nullstamp?(self[col_name])
      return Datet.in(self[col_name])
    end
  end

  # Define various methods based on integer-columns.
  def self.define_numeric_methods(inst_methods, col_name)
    return if inst_methods.include?("#{col_name}_format".to_sym)

    define_method("#{col_name}_format") do |*method_args|
      return Knj::Locales.number_out(self[col_name], *method_args)
    end
  end

  # Define methods to look up objects directly.
  #===Examples
  #  user = Models::User.by_username('John Doe')
  #  print user.id
  def self.define_text_methods(inst_methods, col_name)
    return if inst_methods.include?("by_#{col_name}".to_sym) && RUBY_VERSION.to_s.slice(0, 3) != "1.8"

    define_singleton_method("by_#{col_name}") do |arg|
      return self.class.ob.get_by(self.class.table, col_name.to_s => arg)
    end
  end

  # Defines dbtime-methods based on time-columns.
  def self.define_time_methods(inst_methods, col_name)
    return if inst_methods.include?("#{col_name}_dbt".to_sym)

    define_method("#{col_name}_dbt") do
      return Baza::Db::Dbtime.new(self[col_name.to_sym])
    end
  end

  # Memory friendly helper method that defines methods for 'has_many'.
  def self.define_many_methods(classname, methodname, colname, where_args)
    define_method(methodname) do |*args, &block|
      if args && args[0]
        list_args = args[0]
      else
        list_args = {}
      end

      list_args.merge!(where_args) if where_args
      list_args[colname.to_s] = id

      self.class.ob.list(classname, list_args, &block)
    end

    define_method("#{methodname}_count".to_sym) do |*args|
      list_args = args[0] if args && args[0]
      list_args = {} unless list_args
      list_args[colname.to_s] = id
      list_args["count"] = true

      self.class.ob.list(classname, list_args)
    end

    define_method("#{methodname}_last".to_sym) do |args|
      args = {} unless args
      self.class.ob.list(classname, {"orderby" => [["id", "desc"]], "limit" => 1}.merge(args))
    end
  end

  # Memory friendly helper method that defines methods for 'has_one'.
  def self.define_one_methods(classname, methodname, colname)
    define_method(methodname) do
      self.class.ob.get_try(self, colname, classname)
    end

    methodname_html = "#{methodname}_html".to_sym
    define_method(methodname_html) do |*args|
      obj = __send__(methodname)
      return self.class.ob.events.call(:no_html, classname) unless obj

      raise "Class '#{classname}' does not have a 'html'-method." unless obj.respond_to?(:html)
      obj.html(*args)
    end

    methodname_name = "#{methodname}_name".to_sym
    define_method(methodname_name) do |*args|
      obj = __send__(methodname)
      return self.class.ob.events.call(:no_name, classname) unless obj
      obj.name(*args)
    end
  end

  # Returns a hash reflection the current ActiveRecord model and its current values (not like .attributes which reflects the old values).
  def self.activerecord_to_hash(model)
    attrs = {}
    model.attribute_names.each do |name|
      attrs[name] = model.__send__(name)
    end

    attrs
  end
end
