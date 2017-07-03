class Baza::Driver::Pg::Database < Baza::Database
  def save!
    rename(name) unless name.to_s == name_was
    self
  end

  def drop
    other_db = @db.databases.list.find { |database| database.name != @db.current_database }

    # Drop database through a cloned connection, because Postgres might bug up if dropping the current
    @db.clone_conn(db: other_db.name) do |cloned_conn|
      # Close existing connections to avoid 'is being accessed by other users' errors
      cloned_conn.query("REVOKE CONNECT ON DATABASE #{@db.sep_database}#{@db.escape_database(name)}#{@db.sep_database} FROM public")
      cloned_conn.query("SELECT pid, pg_terminate_backend(pid) FROM pg_stat_activity WHERE datname = #{@db.sep_val}#{@db.esc(name)}#{@db.sep_val} AND pid != pg_backend_pid()")

      # Drop the database
      cloned_conn.query("DROP DATABASE #{@db.sep_database}#{@db.escape_database(name)}#{@db.sep_database}")
    end

    self
  end

  def table(table_name)
    table = tables(name: table_name).first
    raise Baza::Errors::TableNotFound unless table
    table
  end

  def tables(args = {})
    tables_list = [] unless block_given?

    where_args = {
      table_catalog: name,
      table_schema: "public"
    }
    where_args[:table_name] = args.fetch(:name) if args[:name]

    use do
      @db.select([:information_schema, :tables], where_args, orderby: :table_name) do |table_data|
        table = Baza::Driver::Pg::Table.new(
          driver: @db.driver,
          data: table_data
        )

        next if table.native?

        if tables_list
          tables_list << table
        else
          yield table
        end
      end
    end

    tables_list
  end

  def use(&blk)
    @db.with_database(name, &blk)
    self
  end

  CREATE_ALLOWED_KEYS = [:columns, :indexes, :temp, :return_sql].freeze
  # Creates a new table by the given name and data.
  def create_table(table_name, data, args = nil)
    use do
      @db.tables.create(table_name, data, args)
    end
  end

  def rename(new_name)
    @db.query("ALTER DATABASE #{@db.sep_database}#{@db.escape_database(name_was)}#{@db.sep_database} RENAME TO #{@db.sep_database}#{@db.escape_database(new_name)}#{@db.sep_database}")
    @name = new_name.to_s
    self
  end
end
