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
end
