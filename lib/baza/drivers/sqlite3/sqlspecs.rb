class Baza::Driver::Sqlite3::Sqlspecs < Baza::Sqlspecs
  def strftime(val, col_str)
    return "STRFTIME('#{val}', SUBSTR(#{col_str}, 0, 20))"
  end
end
