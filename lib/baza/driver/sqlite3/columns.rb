# This class handels the SQLite3-specific behaviour for columns.
class Baza::Driver::Sqlite3::Columns
  attr_reader :db

  # Constructor. This should not be called manually.
  def initialize(args)
    @db = args.fetch(:db)
  end

  DATA_SQL_ALLOWED_KEYS = [:foreign_key, :name, :type, :maxlength, :autoincr, :primarykey, :null, :default, :default_func, :renames, :after, :renames].freeze
  # Returns SQL for a knjdb-compatible hash.
  def data_sql(data)
    data.each_key do |key|
      raise "Invalid key: '#{key}' (#{key.class.name})." unless DATA_SQL_ALLOWED_KEYS.include?(key)
    end

    raise "No type given." unless data[:type]
    type = data[:type].to_sym

    if type == :enum
      type = :varchar
      data.delete(:maxlength)
    end

    data[:maxlength] = 255 if type == :varchar && !data.key?(:maxlength)
    data[:maxlength] = 11 if type == :int && !data.key?(:maxlength) && !data[:autoincr] && !data[:primarykey]
    type = :integer if @db.int_types.index(type) && (data[:autoincr] || data[:primarykey])

    sql = "`#{data.fetch(:name)}` #{type}"
    sql << "(#{data.fetch(:maxlength)})" if data[:maxlength] && !data[:autoincr]
    sql << " PRIMARY KEY" if data[:primarykey]
    sql << " AUTOINCREMENT" if data[:autoincr]

    if !data[:null] && data.key?(:null)
      sql << " NOT NULL"
      data[:default] = 0 if !data.key?(:default) || !data[:default] && type == :int
    end

    if data.key?(:default_func)
      sql << " DEFAULT #{data[:default_func]}"
    elsif data.key?(:default) && data[:default] != false
      sql << " DEFAULT #{@db.quote_value(data.fetch(:default))}"
    end

    sql
  end
end
