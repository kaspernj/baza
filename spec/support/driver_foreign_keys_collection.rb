shared_examples_for "a baza foreign keys driver" do
  let(:driver) { constant.new }
  let(:db) { driver.db }
  let(:posts_table) do
    db.tables.create(
      "posts",
      columns: [
        {name: "id", type: :int, autoincr: true, primarykey: true},
        {name: "user_id", type: :int},
        {name: "text", type: :varchar}
      ]
    )
    db.tables[:posts]
  end
  let(:users_table) do
    db.tables.create(
      "users",
      columns: [
        {name: "id", type: :int, autoincr: true, primarykey: true},
        {name: "email", type: :varchar}
      ]
    )
    db.tables[:users]
  end
  let(:users_id_column) { users_table.column("id") }

  before do
    driver.before
  end

  after do
    driver.after
  end

  it "creates foreign keys" do
    posts_table.column("user_id").create_foreign_key(
      column: users_id_column,
      name: "test_column_key"
    )

    expect(posts_table.foreign_keys.length).to eq 1
    expect(posts_table.foreign_key("test_column_key").name).to eq "test_column_key"
  end
end
