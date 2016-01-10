class Baza::SqlQueries::NonAtomicUpsert
  def initialize(args)
    @db = args.fetch(:db)
    @table_name = args.fetch(:table_name)
    @updates = args.fetch(:updates)
    @terms = args.fetch(:terms)
    @buffer = args[:buffer]
  end

  def execute
    row = @db.single(@table_name, @terms)

    if @buffer
      obj = @buffer
    else
      obj = @db
    end

    if row
      obj.update(@table_name, @updates, @terms)
    else
      obj.insert(@table_name, @terms.merge(@updates))
    end
  end
end
