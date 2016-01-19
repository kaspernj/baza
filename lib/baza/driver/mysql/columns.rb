class Baza::Driver::Mysql::Columns
  def initialize(args)
    @db = args.fetch(:db)
  end

  DATA_SQL_ALLOWED_KEYS = [:type, :maxlength, :name, :primarykey, :autoincr, :default, :comment, :after, :first, :storage, :null, :renames]
  def data_sql(data)
    data.each_key do |key|
      raise "Invalid key: '#{key}' (#{key.class.name})." unless DATA_SQL_ALLOWED_KEYS.include?(key)
    end

    raise "No type given." unless data[:type]
    type = data[:type].to_sym

    data[:maxlength] = 255 if type == :varchar && data[:maxlength].to_s.strip.length == 0

    sql = "#{@db.sep_col}#{@db.escape_column(data.fetch(:name))}#{@db.sep_col} #{type}"
    sql << "(#{data[:maxlength]})" if data[:maxlength]
    sql << " PRIMARY KEY" if data[:primarykey]
    sql << " AUTO_INCREMENT" if data[:autoincr]
    sql << " NOT NULL" unless data[:null]

    if data.key?(:default_func)
      sql << " DEFAULT #{data[:default_func]}"
    elsif data.key?(:default) && !data[:default].nil?
      sql << " DEFAULT #{@db.sqlval(data.fetch(:default))}"
    end

    sql << " COMMENT '#{@db.escape(data.fetch(:comment))}'" if data.key?(:comment)
    sql << " AFTER #{@db.sep_col}#{@db.escape_column(data.fetch(:after))}#{@db.sep_col}" if data[:after] && !data[:first]
    sql << " FIRST" if data[:first]
    sql << " STORAGE #{data[:storage].to_s.upcase}" if data[:storage]

    sql
  end
end
