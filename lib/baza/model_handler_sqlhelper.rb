require "ostruct"

class Baza::ModelHandler
  # This method helps build SQL from Objects-instances list-method. It should not be called directly but only through Objects.list.
  def sqlhelper(list_args, args_def)
    args = args_def

    if args[:db]
      db = args[:db]
    else
      db = @args[:db]
    end

    if args[:table]
      table_def = "`#{db.escape_table(args[:table])}`."
    else
      table_def = ""
    end

    sql_joins = ""
    sql_where = ""
    sql_order = ""
    sql_limit = ""
    sql_groupby = ""

    do_joins = {}

    limit_from = nil
    limit_to = nil

    if list_args.key?("orderby")
      orders = []
      orderstr = list_args["orderby"]
      list_args["orderby"] = [list_args["orderby"]] if list_args["orderby"].is_a?(Hash)

      if list_args["orderby"].is_a?(String)
        found = false
        found = true if args[:cols].key?(orderstr)

        if found
          sql_order << " ORDER BY "
          ordermode = " ASC"
          if list_args.key?("ordermode")
            if list_args["ordermode"] == "desc"
              ordermode = " DESC"
            elsif list_args["ordermode"] == "asc"
              ordermode = " ASC"
              raise "Unknown ordermode: #{list_args["ordermode"]}"
            end

            list_args.delete("ordermode")
          end

          sql_order << "#{table_def}`#{db.escape_column(list_args["orderby"])}`#{ordermode}"
          list_args.delete("orderby")
        end
      elsif list_args["orderby"].is_a?(Array)
        sql_order << " ORDER BY "

        list_args["orderby"].each do |val|
          ordermode = nil
          orderstr = nil
          found = false

          if val.is_a?(Array)
            if val[1] == "asc"
              ordermode = " ASC"
            elsif val[1] == "desc"
              ordermode = " DESC"
            end

            if val[0].is_a?(Array)
              if args[:joined_tables]
                args[:joined_tables].each do |table_name, _table_data|
                  next if table_name.to_s != val[0][0].to_s
                  do_joins[table_name] = true
                  orders << "`#{db.escape_table(table_name)}`.`#{db.escape_column(val[0][1])}`#{ordermode}"
                  found = true
                  break
                end
              end

              raise "Could not find joined table for ordering: '#{val[0][0]}'." unless found
            else
              orderstr = val[0]
            end
          elsif val.is_a?(String)
            orderstr = val
            ordermode = " ASC"
          elsif val.is_a?(Hash) && val[:type] == :sql
            orders << val[:sql]
            found = true
          elsif val.is_a?(Hash) && val[:type] == :case
            caseorder = " CASE"

            val[:case].each do |key, caseval|
              col = key.first
              isval = key.last
              col_str = nil

              if col.is_a?(Array)
                raise "No joined tables for '#{args[:table]}'." unless args[:joined_tables]

                found = false
                args[:joined_tables].each do |table_name, _table_data|
                  next unless table_name == col.first
                  do_joins[table_name] = true
                  col_str = "`#{db.escape_table(table_name)}`.`#{db.escape_column(col.last)}`"
                  found = true
                  break
                end

                raise "No such joined table on '#{args[:table]}': '#{col.first}' (#{col.first.class.name}) with the following joined table:\n#{Php4r.print_r(args[:joined_tables], true)}" unless found
              elsif col.is_a?(String) || col.is_a?(Symbol)
                col_str = "#{table_def}`#{col}`"
                found = true
              else
                raise "Unknown type for case-ordering: '#{col.class.name}'."
              end

              raise "'colstr' was not set." unless col_str
              caseorder << " WHEN #{col_str} = '#{db.esc(isval)}' THEN '#{db.esc(caseval)}'"
            end

            caseorder << " ELSE '#{db.esc(val[:else])}'" if val[:else]

            caseorder << " END"
            orders << caseorder
          elsif val.is_a?(Hash)
            raise "No joined tables." unless args.key?(:joined_tables)

            if val[:mode] == "asc"
              ordermode = " ASC"
            elsif val[:mode] == "desc"
              ordermode = " DESC"
            end

            if args[:joined_tables]
              args[:joined_tables].each do |table_name, table_data|
                if table_data[:parent_table]
                  table_name_real = table_name
                elsif table_data[:datarow]
                  table_name_real = datarow_from_datarow_argument(table_data[:datarow]).classname
                else
                  table_name_real = @args[:module].const_get(table_name).classname
                end

                next unless table_name.to_s == val[:table].to_s
                do_joins[table_name] = true

                if val[:sql]
                  orders << val[:sql]
                elsif val[:col]
                  orders << "`#{db.escape_table(table_name_real)}`.`#{db.escape_column(val[:col])}`#{ordermode}"
                else
                  raise "Couldnt figure out how to order based on keys: '#{val.keys.sort}'."
                end

                found = true
                break
              end
            end
          else
            raise "Unknown object: #{val.class.name}"
          end

          found = true if args[:cols].key?(orderstr)

          raise "Column not found for ordering: #{orderstr}." unless found

          orders << "#{table_def}`#{db.escape_column(orderstr)}`#{ordermode}" if orderstr
        end

        sql_order << orders.join(", ")
        list_args.delete("orderby")
      else
        raise "Unknown orderby object: #{list_args["orderby"].class.name}."
      end
    end

    list_args.each do |realkey, val|
      found = false

      if realkey.is_a?(Array)
        if !args[:joins_skip]
          datarow_obj = datarow_obj_from_args(args_def, list_args, realkey[0])
          args = datarow_obj.columns_sqlhelper_args
          raise "Couldnt get arguments from SQLHelper." unless args
        else
          datarow_obj = @args[:module].const_get(realkey[0])
          args = args_def
        end

        table_sym = realkey[0].to_sym
        do_joins[table_sym] = true
        list_table_name_real = table_sym
        table = "`#{db.escape_table(list_table_name_real)}`."
        key = realkey[1]
      else
        table = table_def
        args = args_def
        key = realkey
      end

      if args.key?(:cols_bools) && !args[:cols_bools].index(key).nil?
        val_s = val.to_s

        if val_s == "1" || val_s == "true"
          realval = "1"
        elsif val_s == "0" || val_s == "false"
          realval = "0"
        else
          raise "Could not make real value out of class: #{val.class.name} => #{val}."
        end

        sql_where << " AND #{table}`#{db.escape_column(key)}` = '#{db.esc(realval)}'"
        found = true
      elsif args[:cols].key?(key.to_s)
        if val.is_a?(Array)
          if val.empty? && db.opts[:type].to_s == "mysql"
            sql_where << " AND false"
          else
            escape_sql = val.map { |v| "'#{db.escape(v)}'" }.join(",")
            sql_where << " AND #{table}`#{db.escape_column(key)}` IN (#{escape_sql})"
          end
        elsif val.is_a?(Hash) && val[:type].to_sym == :col
          raise "No table was given for join: '#{val}', key: '#{key}' on table #{table}." unless val.key?(:table)
          do_joins[val[:table].to_sym] = true
          sql_where << " AND #{table}`#{db.escape_column(key)}` = `#{db.escape_table(val[:table])}`.`#{db.escape_column(val[:name])}`"
        elsif val.is_a?(Hash) && val[:type] == :sqlval && val[:val] == :null
          sql_where << " AND #{table}`#{db.escape_column(key)}` IS NULL"
        elsif val.is_a?(Proc)
          call_args = OpenStruct.new(ob: self, db: db)
          sql_where << " AND #{table}`#{db.escape_column(key)}` = '#{db.esc(val.call(call_args))}'"
        else
          sql_where << " AND #{table}`#{db.escape_column(key)}` = '#{db.esc(val)}'"
        end

        found = true
      elsif key.to_s == "limit_from"
        limit_from = val.to_i
        found = true
      elsif key.to_s == "limit_to"
        limit_to = val.to_i
        found = true
      elsif key.to_s == "limit"
        limit_from = 0
        limit_to = val.to_i
        found = true
      elsif args.key?(:cols_dbrows) && !args[:cols_dbrows].index("#{key}_id").nil?
        if val == false
          sql_where << " AND #{table}`#{db.escape_column(key.to_s + "_id")}` = '0'"
        elsif val.is_a?(Array)
          if val.empty?
            sql_where << " AND false"
          else
            sql_where << " AND #{table}`#{db.escape_column("#{key}_id")}` IN (#{Knj::ArrayExt.join(arr: val, sep: ",", surr: "'", callback: proc { |obj| obj.id.sql })})"
          end
        else
          sql_where << " AND #{table}`#{db.escape_column(key.to_s + "_id")}` = '#{db.esc(val.id)}'"
        end

        found = true
      elsif match = key.match(/^([A-z_\d]+)_(search|has)$/) && !args[:cols].key?(match[1]).nil?
        if match[2] == "search"
          Knj::Strings.searchstring(val).each do |str|
            sql_where << " AND #{table}`#{db.escape_column(match[1])}` LIKE '%#{db.esc(str)}%'"
          end
        elsif match[2] == "has"
          if val
            sql_where << " AND #{table}`#{db.escape_column(match[1])}` != ''"
          else
            sql_where << " AND #{table}`#{db.escape_column(match[1])}` = ''"
          end
        end

        found = true
      elsif match = key.match(/^([A-z_\d]+)_(not|lower)$/) && args[:cols].key?(match[1])
        if match[2] == "not"
          if val.is_a?(Array)
            if val.empty?
              # ignore.
            else
              escape_sql = Knj::ArrayExt.join(
                arr: val,
                callback: proc do|value|
                  db.escape(value)
                end,
                sep: ",",
                surr: "'"
              )
              sql_where << " AND #{table}`#{db.escape_column(match[1])}` NOT IN (#{escape_sql})"
            end
          else
            sql_where << " AND #{table}`#{db.escape_column(match[1])}` != '#{db.esc(val)}'"
          end
        elsif match[2] == "lower"
          sql_where << " AND LOWER(#{table}`#{db.escape_column(match[1])}`) = LOWER('#{db.esc(val)}')"
        else
          raise "Unknown mode: '#{match[2]}'."
        end

        found = true
      elsif args.key?(:cols_date) && (match = key.match(/^(.+)_(day|week|month|year|from|to|below|above)(|_(not))$/)) && !args[:cols_date].index(match[1]).nil?
        not_v = match[4]
        val = Datet.in(val) if val.is_a?(Time)

        if match[2] == "day"
          if val.is_a?(Array)
            sql_where << " AND ("
            first = true

            val.each do |dayval|
              if first
                first = false
              else
                sql_where << " OR "
              end

              sql_where << "#{db.sqlspecs.strftime("%d %m %Y", "#{table}`#{db.escape_column(match[1])}`")} #{self.not(not_v, "!")}= #{db.sqlspecs.strftime("%d %m %Y", "'#{db.esc(dayval.dbstr)}'")}"
            end

            sql_where << ")"
          else
            sql_where << " AND #{db.sqlspecs.strftime("%d %m %Y", "#{table}`#{db.escape_column(match[1])}`")} #{self.not(not_v, "!")}= #{db.sqlspecs.strftime("%d %m %Y", "'#{db.esc(val.dbstr)}'")}"
          end
        elsif match[2] == "week"
          sql_where << " AND #{db.sqlspecs.strftime("%W %Y", "#{table}`#{db.escape_column(match[1])}`")} #{self.not(not_v, "!")}= #{db.sqlspecs.strftime("%W %Y", "'#{db.esc(val.dbstr)}'")}"
        elsif match[2] == "month"
          sql_where << " AND #{db.sqlspecs.strftime("%m %Y", "#{table}`#{db.escape_column(match[1])}`")} #{self.not(not_v, "!")}= #{db.sqlspecs.strftime("%m %Y", "'#{db.esc(val.dbstr)}'")}"
        elsif match[2] == "year"
          sql_where << " AND #{db.sqlspecs.strftime("%Y", "#{table}`#{db.escape_column(match[1])}`")} #{self.not(not_v, "!")}= #{db.sqlspecs.strftime("%Y", "'#{db.esc(val.dbstr)}'")}"
        elsif match[2] == "from" || match[2] == "above"
          sql_where << " AND #{table}`#{db.escape_column(match[1])}` >= '#{db.esc(val.dbstr)}'"
        elsif match[2] == "to" || match[2] == "below"
          sql_where << " AND #{table}`#{db.escape_column(match[1])}` <= '#{db.esc(val.dbstr)}'"
        else
          raise "Unknown date-key: #{match[2]}."
        end

        found = true
      elsif args.key?(:cols_num) && match = key.match(/^(.+)_(from|to|above|below|numeric)$/) && !args[:cols_num].index(match[1]).nil?
        if match[2] == "from"
          sql_where << " AND #{table}`#{db.escape_column(match[1])}` >= '#{db.esc(val)}'"
        elsif match[2] == "to"
          sql_where << " AND #{table}`#{db.escape_column(match[1])}` <= '#{db.esc(val)}'"
        elsif match[2] == "above"
          sql_where << " AND #{table}`#{db.escape_column(match[1])}` > '#{db.esc(val)}'"
        elsif match[2] == "below"
          sql_where << " AND #{table}`#{db.escape_column(match[1])}` < '#{db.esc(val)}'"
        else
          raise "Unknown method of treating cols-num-argument: #{match[2]}."
        end

        found = true
      elsif match = key.match(/^(.+)_lookup$/) && args[:cols].key?("#{match[1]}_id") && args[:cols].key?("#{match[1]}_class")
        sql_where << " AND #{table}`#{db.escape_column("#{match[1]}_class")}` = '#{db.esc(val.table)}'"
        sql_where << " AND #{table}`#{db.escape_column("#{match[1]}_id")}` = '#{db.esc(val.id)}'"
        found = true
      elsif realkey == "groupby"
        found = true

        if val.is_a?(Array)
          val.each do |col_name|
            raise "Column '#{val}' not found on table '#{table}'." unless args[:cols].key?(col_name)
            sql_groupby << ", " if sql_groupby.length > 0
            sql_groupby << "#{table}`#{db.escape_column(col_name)}`"
          end
        elsif val.is_a?(String)
          sql_groupby << ", " if sql_groupby.length > 0
          sql_groupby << "#{table}`#{db.escape_column(val)}`"
        else
          raise "Unknown class given for 'groupby': '#{val.class.name}'."
        end
      end

      list_args.delete(realkey) if found
    end

    args = args_def

    unless args[:joins_skip]
      raise "No joins defined on '#{args[:table]}' for: '#{args[:table]}'." if !do_joins.empty? && !args[:joined_tables]

      do_joins.each do |table_name, _temp_val|
        raise "No join defined on table '#{args[:table]}' for table '#{table_name}'." unless args[:joined_tables].key?(table_name)
        table_data = args[:joined_tables][table_name]

        if table_data.key?(:parent_table)
          join_table_name_real = table_name
          sql_joins << " LEFT JOIN `#{table_data[:parent_table]}` AS `#{table_name}` ON 1=1"
        else
          const = @args[:module].const_get(table_name)
          join_table_name_real = const.classname
          sql_joins << " LEFT JOIN `#{const.table}` AS `#{const.classname}` ON 1=1"
        end

        if table_data[:ob]
          ob = table_data[:ob]
        else
          ob = self
        end

        class_name = args[:table].to_sym

        if table_data[:datarow]
          datarow = datarow_from_datarow_argument(table_data[:datarow])
        else
          requireclass(class_name) if @objects.key?(class_name)
          datarow = @args[:module].const_get(class_name)
        end

        unless datarow.columns_sqlhelper_args
          ob.requireclass(datarow.table.to_sym)
          raise "No SQL-helper-args on class '#{datarow.table}' ???" unless datarow.columns_sqlhelper_args
        end

        newargs = datarow.columns_sqlhelper_args.clone
        newargs[:table] = join_table_name_real
        newargs[:joins_skip] = true

        # Clone the where-arguments and run them against another sqlhelper to sub-join.
        join_args = table_data[:where].clone
        ret = sqlhelper(join_args, newargs)
        sql_joins << ret[:sql_where]

        # If any of the join-arguments are left, then we should throw an error.
        join_args.each_key do |key|
          raise "Invalid key '#{key}' when trying to join table '#{table_name}' on table '#{args_def[:table]}'."
        end
      end
    end

    # If limit arguments has been given then add them.
    sql_limit = " LIMIT #{limit_from}, #{limit_to}" if limit_from && limit_to

    sql_groupby = nil if sql_groupby.empty?

    {
      sql_joins: sql_joins,
      sql_where: sql_where,
      sql_limit: sql_limit,
      sql_order: sql_order,
      sql_groupby: sql_groupby
    }
  end

  # Used by sqlhelper-method to look up datarow-classes and automatically load them if they arent loaded already.
  def datarow_obj_from_args(args, _list_args, class_name)
    class_name = class_name.to_sym

    unless args.key?(:joined_tables)
      raise "No joined tables on '#{args[:table]}' to find datarow for: '#{class_name}'."
    end

    args[:joined_tables].each do |table_name, table_data|
      next if table_name.to_sym != class_name
      return datarow_from_datarow_argument(table_data[:datarow]) if table_data[:datarow]

      requireclass(class_name) if @objects.key?(class_name)
      return @args[:module].const_get(class_name)
    end

    raise "Could not figure out datarow for: '#{class_name}'."
  end

  def datarow_from_datarow_argument(datarow_argument)
    if datarow_argument.is_a?(String)
      const = Knj::Strings.const_get_full(datarow_argument)
    else
      const = datarow_argument
    end

    load_class(datarow_argument.to_s.split("::").last) unless const.initialized? # Make sure the class is initialized.

    const
  end

  def not(not_v, val)
    return val if not_v == "not" || not_v == "not_"

    ""
  end
end
