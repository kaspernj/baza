require "spec_helper"

describe Baza::Cloner do
  it "can clone drivers" do
    require "info_active_record_mysql2"
    conn = Baza::InfoActiveRecordMysql2.connection
    baza_db = Baza::Cloner.from_active_record_connection(conn[:conn])
    expect(baza_db.query("SELECT 1 AS test").fetch[:test].to_s).to eq "1"
  end
end
