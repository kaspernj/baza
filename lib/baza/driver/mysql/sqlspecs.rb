class Baza::Driver::Mysql::Sqlspecs < Baza::Sqlspecs
  def strftime(val, colstr)
    "DATE_FORMAT(#{colstr}, '#{val}')"
  end
end
