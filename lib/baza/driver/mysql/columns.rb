class Baza::Driver::Mysql::Columns
  def initialize(args)
    @db = args.fetch(:db)
  end

  DATA_SQL_ALLOWED_KEYS = %i[foreign_key type maxlength name primarykey autoincr default comment after first storage null renames].freeze
  def data_sql(data)
    data.each_key do |key|
      raise "Invalid key: '#{key}' (#{key.class.name})." unless DATA_SQL_ALLOWED_KEYS.include?(key)
    end

    raise "No type given." unless data[:type]
    type = data[:type].to_sym

    data[:maxlength] = 255 if type == :varchar && data[:maxlength].to_s.strip.empty?

    sql = "#{@db.quote_column(data.fetch(:name))} #{type}"
    sql << "(#{data[:maxlength]})" if data[:maxlength]
    sql << " PRIMARY KEY" if data[:primarykey]
    sql << " AUTO_INCREMENT" if data[:autoincr]
    sql << " NOT NULL" if data.key?(:null) && !data[:null]

    if data.key?(:default_func)
      sql << " DEFAULT #{data[:default_func]}"
    elsif data.key?(:default) && !data[:default].nil?
      sql << " DEFAULT #{@db.quote_value(data.fetch(:default))}"
    end

    sql << " COMMENT #{@db.quote_value(data.fetch(:comment))}" if data.key?(:comment)
    sql << " AFTER #{@db.quote_column(data.fetch(:after))}" if data[:after] && !data[:first]
    sql << " FIRST" if data[:first]
    sql << " STORAGE #{data[:storage].to_s.upcase}" if data[:storage]

    sql
  end
end
