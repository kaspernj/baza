class Baza::Column
  def to_s
    "#<#{self.class.name} name=\"#{name}\" type=\"#{type}\" maxlength=\"#{maxlength}\" autoincr=\"#{autoincr?}\" primarykey=\"#{primarykey?}\">"
  end

  def inspect
    to_s
  end
end
