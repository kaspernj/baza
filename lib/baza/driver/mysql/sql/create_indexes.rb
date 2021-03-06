class Baza::Driver::Mysql::Sql::CreateIndexes
  def initialize(args)
    @create = args[:create]
    @indexes = args.fetch(:indexes)
    @on_table = args[:on_table]
    @table_name = args.fetch(:table_name)
  end

  def sql
    sql = ""
    first = true

    @indexes.each do |index_data|
      sql << "CREATE" if @create || @create.nil?

      if index_data.is_a?(String) || index_data.is_a?(Symbol)
        index_data = {name: index_data, columns: [index_data]}
      end

      raise "No name was given: '#{index_data}'." if !index_data.key?(:name) || index_data[:name].to_s.strip.empty?
      raise "No columns was given on index: '#{index_data.fetch(:name)}'." if !index_data[:columns] || index_data[:columns].empty?

      if first
        first = false
      else
        sql << ", "
      end

      sql << " UNIQUE" if index_data[:unique]
      sql << " INDEX #{Baza::Driver::Mysql.quote_index(index_data.fetch(:name))}"

      if @on_table || @on_table.nil?
        sql << " ON #{Baza::Driver::Mysql.quote_table(@table_name)}"
      end

      sql << " ("

      first = true
      index_data[:columns].each do |col_name|
        sql << ", " unless first
        first = false if first

        sql << Baza::Driver::Mysql.quote_column(col_name)
      end

      sql << ")"
    end

    [sql]
  end
end
