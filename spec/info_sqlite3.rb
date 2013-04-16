class Baza::InfoSqlite3
  def self.sample_db
    require "sqlite3"
    path = "#{Dir.tmpdir}/baza_sqlite3_test.sqlite3_#{Time.now.to_f.to_s.hash}"
    File.unlink(path) if File.exists?(path)
    db = Baza::Db.new(
      :type => :sqlite3,
      :path => path,
      :index_append_table_name => true,
      :sql_to_error => true
    )
    
    begin
      yield db
    ensure
      db.close
      File.unlink(path)
    end
  end
end