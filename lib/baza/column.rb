class Baza::Column
  include Baza::DatabaseModelFunctionality

  def to_s
    "#<#{self.class.name} name=\"#{name}\" type=\"#{type}\" maxlength=\"#{maxlength}\" autoincr=\"#{autoincr?}\" primarykey=\"#{primarykey?}\">"
  end

  def inspect
    to_s
  end

  def to_param
    name
  end

  def table
    @db.tables[table_name]
  end

  def after
    last = nil
    table.columns.each do |column|
      break if column.name == name
      last = column.name
    end

    last
  end

  def data
    {
      type: type,
      name: name,
      null: null?,
      maxlength: maxlength,
      default: default,
      primarykey: primarykey?,
      autoincr: autoincr?
    }
  end
end
