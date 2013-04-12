class Baza::Driver::Mysql::Indexes
  def initialize(args)
    @args = args
  end
end

class Baza::Driver::Mysql::Indexes::Index
  attr_reader :columns
  
  def initialize(args)
    @args = args
    @columns = []
  end
  
  #Used to validate in Knj::Wrap_map.
  def __object_unique_id__
    return @args[:data][:Key_name]
  end
  
  def name
    return @args[:data][:Key_name]
  end
  
  def table
    return @args[:db].tables[@args[:table_name]]
  end
  
  def drop
    sql = "DROP INDEX `#{self.name}` ON `#{self.table.name}`"
    
    begin
      @args[:db].query(sql)
    rescue => e
      #The index has already been dropped - ignore.
      if e.message.index("check that column/key exists") != nil
        #ignore.
      else
        raise e
      end
    end
  end
  
  def data
    return {
      "name" => name,
      "columns" => @columns
    }
  end
  
  #Returns true if the index is a unique-index.
  def unique?
    if @args[:data][:Index_type] == "UNIQUE"
      return true
    else
      return false
    end
  end
  
  #Returns true if the index is a primary-index.
  def primary?
		return true if @args[:data][:Index_type] == "BTREE"
		return false
  end
  
  #Inspect crashes if this is not present? - knj.
  def to_s
    return "#<#{self.class.name}>"
  end
end