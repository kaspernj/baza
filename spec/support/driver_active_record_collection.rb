require "active_record"
require_relative "../active_record/models/user"

shared_examples_for "an active record driver" do
  let(:driver) { constant.new(type_translation: true) }
  let(:db) { driver.db }
  let(:db_with_type_translation) { constant.new(type_translation: true, debug: false).db }
  let(:row) do
    test_table.insert(text: "Kasper", number: 30, float: 4.5)
    db.select(:test, text: "Kasper").fetch
  end
  let(:test_table) do
    db.tables.create(
      "test",
      columns: [
        {name: "id", type: :int, autoincr: true, primarykey: true},
        {name: "text", type: :varchar},
        {name: "number", type: :int, default: 0},
        {name: "float", type: :float, default: 0.0}
      ]
    )
    db.tables[:test]
  end

  before do
    driver.before

    db.tables.create(
      "users",
      columns: [
        {name: "id", type: :int, autoincr: true, primarykey: true},
        {name: "email", type: :varchar}
      ],
      indexes: [
        {name: "index_on_email", columns: ["email"], unique: true}
      ]
    )
  end

  after do
    driver.after
  end

  it "saves models through baza" do
    user = User.new(email: "test@example.com")
    expect(user.valid?).to be true
    db.driver.save_model!(user, update_on_duplicate_key: true)
    expect(user.persisted?).to be true
    expect(user.id).to eq 1
    expect(user.email).to eq "test@example.com"
  end

  it "upserts" do
    user1 = User.new(email: "test@example.com")
    db.driver.save_model!(user1)

    user2 = User.new(email: "test@example.com")
    db.driver.save_model!(user2, update_on_duplicate_key: true)

    expect(user2.id).to eq user1.id
  end
end
