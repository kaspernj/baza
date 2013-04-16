#This class handels various MySQL-column-specific operations.
class Baza::Driver::Mysql::Columns
  #Constructor. Should not be called manually.
  def initialize(args)
    @args = args
  end
  
  #Returns the SQL for this column.
  DATA_SQL_ALLOWED_KEYS = [:type, :maxlength, :name, :primarykey, :autoincr, :default, :comment, :after, :first, :storage, :null]
  def data_sql(data)
    data.each do |key, val|
      raise "Invalid key: '#{key}' (#{key.class.name})." if !DATA_SQL_ALLOWED_KEYS.include?(key)
    end
    
    raise "No type given." if !data[:type]
    type = data[:type].to_sym
    
    data[:maxlength] = 255 if type == :varchar and !data.key?(:maxlength)
    
    sql = "`#{data[:name]}` #{type}"
    sql << "(#{data[:maxlength]})" if data[:maxlength]
    sql << " PRIMARY KEY" if data[:primarykey]
    sql << " AUTO_INCREMENT" if data[:autoincr]
    sql << " NOT NULL" if !data[:null]
    
    if data.key?(:default_func)
      sql << " DEFAULT #{data[:default_func]}"
    elsif data.key?(:default) and data[:default] != false
      sql << " DEFAULT '#{@args[:db].escape(data[:default])}'"
    end
    
    sql << " COMMENT '#{@args[:db].escape(data[:comment])}'" if data.key?(:comment)
    sql << " AFTER `#{@args[:db].esc_col(data[:after])}`" if data[:after] and !data[:first]
    sql << " FIRST" if data[:first]
    sql << " STORAGE #{data[:storage].to_s.upcase}" if data[:storage]
    
    return sql
  end
end

#This class handels every MySQL-column, that can be returned from a table-object.
class Baza::Driver::Mysql::Columns::Column
  attr_reader :args, :name
  
  #Constructor. Should not be called manually.
  def initialize(args)
    @args = args
    @name = @args[:data][:Field].to_sym
    @db = @args[:db]
  end
  
  #Used to validate in Knj::Wrap_map.
  def __object_unique_id__
    return @name
  end
  
  #Returns the table-object that this column belongs to.
  def table
    return @args[:db].tables[@args[:table_name]]
  end
  
  #Returns all data of the column in the knjdb-format.
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
  
  #Returns the type of the column (integer, varchar etc.).
  def type
    if !@type
      if match = @args[:data][:Type].match(/^([A-z]+)$/)
        @maxlength = false
        @type = match[0].to_sym
      elsif match = @args[:data][:Type].match(/^decimal\((\d+),(\d+)\)$/)
        @maxlength = "#{match[1]},#{match[2]}"
        @type = :decimal
      elsif match = @args[:data][:Type].match(/^enum\((.+)\)$/)
        @maxlength = match[1]
        @type = :enum
      elsif match = @args[:data][:Type].match(/^(.+)\((\d+)\)/)
        @maxlength = match[2].to_i
        @type = match[1].to_sym
      end
      
      raise "Still not type from: '#{@args[:data][:Type]}'." if @type.to_s.strip.empty?
    end
    
    return @type
  end
  
  #Return true if the columns allows null. Otherwise false.
  def null?
    return false if @args[:data][:Null] == "NO"
    return true
  end
  
  #Returns the maxlength.
  def maxlength
    self.type if !@maxlength
    return @maxlength if @maxlength
    return false
  end
  
  #Returns the default value for the column.
  def default
    return false if (self.type == :datetime or self.type == :date) and @args[:data][:Default].to_s.strip.length <= 0
    return false if (self.type == :int or self.type == :bigint) and @args[:data][:Default].to_s.strip.length <= 0
    return false if !@args[:data][:Default]
    return @args[:data][:Default]
  end
  
  #Returns true if the column is the primary key. Otherwise false.
  def primarykey?
    return true if @args[:data][:Key] == "PRI"
    return false
  end
  
  #Returns true if the column is auto-increasing. Otherwise false.
  def autoincr?
    return true if @args[:data][:Extra].include?("auto_increment")
    return false
  end
  
  #Returns the comment for the column.
  def comment
    return @args[:data][:Comment]
  end
  
  #Drops the column from the table.
  def drop
    @args[:db].query("ALTER TABLE `#{@db.esc_table(@args[:table_name])}` DROP COLUMN `#{@db.esc_col(self.name)}`")
    table = self.table.remove_column_from_list(self)
    return nil
  end
  
  #Changes the column properties by the given hash.
  def change(data)
    col_escaped = "`#{@args[:db].esc_col(self.name)}`"
    table_escape = "`#{@args[:db].esc_table(self.table.name)}`"
    newdata = data.clone
    
    newdata[:name] = self.name if !newdata.key?(:name)
    newdata[:type] = self.type if !newdata.key?(:type)
    newdata[:maxlength] = self.maxlength if !newdata.key?(:maxlength) and self.maxlength
    newdata[:null] = self.null? if !newdata.key?(:null)
    newdata[:default] = self.default if !newdata.key?(:default) and self.default
    newdata.delete(:primarykey) if newdata.key?(:primarykey)
    
    drop_add = true if self.name.to_s != newdata[:name].to_s
    
    self.table.__send__(:remove_column_from_list, self) if drop_add
    @args[:db].query("ALTER TABLE #{table_escape} CHANGE #{col_escaped} #{@args[:db].cols.data_sql(newdata)}")
    self.table.__send__(:add_column_to_list, self) if drop_add
  end
end