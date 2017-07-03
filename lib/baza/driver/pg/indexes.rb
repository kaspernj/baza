class Baza::Driver::Pg::Indexes
  attr_reader :db

  def initialize(args)
    @db = args.fetch(:db)
  end

  def create_index(index_list, args = {})
    sqls = Baza::Driver::Pg::CreateIndexSqlCreator.new(db: db, indexes: index_list, create_args: args, on_table: args.fetch(:table_name)).sqls

    unless args[:return_sql]
      db.transaction do
        sqls.each do |sql|
          db.query(sql)
        end
      end
    end

    sqls if args[:return_sql]
  end
end
