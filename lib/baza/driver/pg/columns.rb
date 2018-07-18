class Baza::Driver::Pg::Columns
  def initialize(args)
    @db = args.fetch(:db)
  end

  DATA_SQL_ALLOWED_KEYS = [:type, :maxlength, :name, :primarykey, :autoincr, :default, :comment, :after, :first, :storage, :null, :renames].freeze
  def data_sql(data)
    data.each_key do |key|
      raise "Invalid key: '#{key}' (#{key.class.name})." unless DATA_SQL_ALLOWED_KEYS.include?(key)
    end

    maxlength = data[:maxlength]

    raise "No type given." unless data[:type]
    type = data[:type].to_sym
    type = :timestamp if type == :datetime

    if type == :int && data[:autoincr]
      type = :serial
      maxlength = nil
    end

    if type == :int
      type = :integer
      maxlength = nil
    end

    if type == :tinyint
      type = :smallint
      maxlength = nil
    end

    data[:maxlength] = 255 if type == :varchar && !data.key?(:maxlength)

    sql = "#{@db.quote_column(data.fetch(:name))} #{type}"
    sql << "(#{maxlength})" if maxlength
    sql << " PRIMARY KEY" if data[:primarykey]
    sql << " NOT NULL" if data.key?(:null) && !data[:null]

    if data.key?(:default_func)
      sql << " DEFAULT #{data[:default_func]}"
    elsif data.key?(:default) && data[:default]
      sql << " DEFAULT #{@db.quote_value(data.fetch(:default))}"
    end

    sql << " COMMENT #{@db.quote_value(data.fetch(:comment))}" if data.key?(:comment)
    sql << " AFTER #{@db.quote_column(data.fetch(:after))}" if data[:after] && !data[:first]
    sql << " FIRST" if data[:first]
    sql << " STORAGE #{data[:storage].to_s.upcase}" if data[:storage]

    sql
  end
end
