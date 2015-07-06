#This class handels various MySQL-column-specific operations.
class Baza::Driver::Mysql::Columns
  #Constructor. Should not be called manually.
  def initialize(args)
    @args = args
  end

  #Returns the SQL for this column.
  DATA_SQL_ALLOWED_KEYS = [:type, :maxlength, :name, :primarykey, :autoincr, :default, :comment, :after, :first, :storage, :null, :renames]
  def data_sql(data)
    data.each do |key, val|
      raise "Invalid key: '#{key}' (#{key.class.name})." if !DATA_SQL_ALLOWED_KEYS.include?(key)
    end

    raise "No type given." unless data[:type]
    type = data[:type].to_sym

    data[:maxlength] = 255 if type == :varchar && !data.key?(:maxlength)

    sql = "`#{data[:name]}` #{type}"
    sql << "(#{data[:maxlength]})" if data[:maxlength]
    sql << " PRIMARY KEY" if data[:primarykey]
    sql << " AUTO_INCREMENT" if data[:autoincr]
    sql << " NOT NULL" if !data[:null]

    if data.key?(:default_func)
      sql << " DEFAULT #{data[:default_func]}"
    elsif data.key?(:default) && data[:default] != false
      sql << " DEFAULT '#{@args[:db].escape(data[:default])}'"
    end

    sql << " COMMENT '#{@args[:db].escape(data[:comment])}'" if data.key?(:comment)
    sql << " AFTER `#{@args[:db].esc_col(data[:after])}`" if data[:after] && !data[:first]
    sql << " FIRST" if data[:first]
    sql << " STORAGE #{data[:storage].to_s.upcase}" if data[:storage]

    return sql
  end
end
