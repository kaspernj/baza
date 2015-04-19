class Baza::Table
  def to_s
    "#<#{self.class.name} name=\"#{name}\">"
  end

  def inspect
    to_s
  end
end
