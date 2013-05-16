#This class handels the SQLite3-specific behaviour for columns.
class Baza::Driver::Sqlite3::Columns
  attr_reader :db
  
  #Constructor. This should not be called manually.
  def initialize(args)
    @args = args
  end
  
  DATA_SQL_ALLOWED_KEYS = [:name, :type, :maxlength, :autoincr, :primarykey, :null, :default, :default_func, :renames, :after, :renames]
  #Returns SQL for a knjdb-compatible hash.
  def data_sql(data)
    data.each do |key, val|
      raise "Invalid key: '#{key}' (#{key.class.name})." unless DATA_SQL_ALLOWED_KEYS.include?(key)
    end
    
    raise "No type given." if !data[:type]
    type = data[:type].to_sym
    
    if type == :enum
      type = :varchar
      data.delete(:maxlength)
    end
    
    data[:maxlength] = 255 if type == :varchar and !data.key?(:maxlength)
    data[:maxlength] = 11 if type == :int and !data.key?(:maxlength) and !data[:autoincr] and !data[:primarykey]
    type = :integer if @args[:db].int_types.index(type) and (data[:autoincr] or data[:primarykey])
    
    sql = "`#{data[:name]}` #{type}"
    sql << "(#{data[:maxlength]})" if data[:maxlength] and !data[:autoincr]
    sql << " PRIMARY KEY" if data[:primarykey]
    sql << " AUTOINCREMENT" if data[:autoincr]
    
    if !data[:null] and data.key?(:null)
      sql << " NOT NULL"
      data[:default] = 0 if type == :int if !data.key?(:default) or !data[:default]
    end
    
    if data.key?(:default_func)
      sql << " DEFAULT #{data[:default_func]}"
    elsif data.key?(:default) and data[:default] != false
      sql << " DEFAULT '#{@args[:db].escape(data[:default])}'"
    end
    
    return sql
  end
end

#This class handels all the SQLite3-columns.
class Baza::Driver::Sqlite3::Columns::Column
  attr_reader :args
  
  #Constructor. This should not be called manually.
  def initialize(args)
    @args = args
    @db = @args[:db]
  end
  
  #Returns the name of the column.
  def name
    return @args[:data][:name]
  end
  
  #Returns the columns table-object.
  def table
    return @db.tables[@args[:table_name]]
  end
  
  #Returns the data of the column as a hash in knjdb-format.
  def data
    return {
      :type => self.type,
      :name => self.name,
      :null => self.null?,
      :maxlength => self.maxlength,
      :default => self.default,
      :primarykey => self.primarykey?,
      :autoincr => self.autoincr?
    }
  end
  
  #Returns the type of the column.
  def type
    if !@type
      if match = @args[:data][:type].match(/^([A-z]+)$/)
        @maxlength = false
        type = match[0].to_sym
      elsif match = @args[:data][:type].match(/^decimal\((\d+),(\d+)\)$/)
        @maxlength = "#{match[1]},#{match[2]}"
        type = :decimal
      elsif match = @args[:data][:type].match(/^enum\((.+)\)$/)
        @maxlength = match[1]
        type = :enum
      elsif match = @args[:data][:type].match(/^(.+)\((\d+)\)$/)
        @maxlength = match[2]
        type = match[1].to_sym
      elsif @args[:data].key?(:type) and @args[:data][:type].to_s == ""
        #A type can actually be empty in SQLite... Wtf?
        return @args[:data][:type]
      end
      
      if type == :integer
        @type = :int
      else
        @type = type
      end
      
      raise "Still not type? (#{@args[:data]})" if @type.to_s.strip.length <= 0
    end
    
    return @type
  end
  
  #Returns true if the column allows null. Otherwise false.
  def null?
    return false if @args[:data][:notnull].to_i == 1
    return true
  end
  
  #Returns the maxlength of the column.
  def maxlength
    self.type if !@maxlength
    return @maxlength if @maxlength
    return false
  end
  
  #Returns the default value of the column.
  def default
    def_val = @args[:data][:dflt_value]
    if def_val.to_s.slice(0..0) == "'"
      def_val = def_val.to_s.slice(0)
    end
    
    if def_val.to_s.slice(-1..-1) == "'"
      def_val = def_val.to_s.slice(0, def_val.length - 1)
    end
    
    return false if @args[:data][:dflt_value].to_s.empty?
    return def_val
  end
  
  #Returns true if the column is the primary key.
  def primarykey?
    return false if @args[:data][:pk].to_i == 0
    return true
  end
  
  #Returns true if the column is auto-increasing.
  def autoincr?
    return true if @args[:data][:pk].to_i == 1 and @args[:data][:type].to_sym == :integer
    return false
  end
  
  #Drops the column from the table.
  def drop
    self.table.copy(:drops => self.name)
  end
  
  #Changes data on the column. Like the name, type, maxlength or whatever.
  def change(data)
    newdata = data.clone
    
    newdata[:name] = self.name if !newdata.key?(:name)
    newdata[:type] = self.type if !newdata.key?(:type)
    newdata[:maxlength] = self.maxlength if !newdata.key?(:maxlength) and self.maxlength
    newdata[:null] = self.null? if !newdata.key?(:null)
    newdata[:default] = self.default if !newdata.key?(:default)
    newdata[:primarykey] = self.primarykey? if !newdata.key?(:primarykey)
    
    @type = nil
    @maxlength = nil
    
    new_table = self.table.copy(
      :alter_columns => {
        self.name.to_sym => newdata
      }
    )
  end
end