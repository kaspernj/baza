class Baza::Index
  include Baza::DatabaseModelFunctionality

  def to_s
    "#<#{self.class.name} name: \"#{name}\" unique=\"#{unique?}\" columns: #{@columns}>"
  end

  def inspect
    to_s
  end

  def to_param
    name
  end
end
