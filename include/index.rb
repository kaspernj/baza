class Baza::Index
  def to_s
    "#<#{self.class.name} name: \"#{name}\" unique=\"#{unique?}\" columns: #{@columns}>"
  end

  def inspect
    to_s
  end
end
