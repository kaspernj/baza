class Baza::Tables
  def exists?(name)
    list(name: name).any? { |table| table.name.to_s == name.to_s }
  end
end
