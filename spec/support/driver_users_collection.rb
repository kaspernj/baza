require "spec_helper"

shared_examples_for "a baza users driver" do
  let(:driver) { constant.new }
  let(:db) { driver.db }
  let(:test_user_name) { "baza-test-create" }
  let(:user) { db.users.create(name: test_user_name, host: "localhost", password: "mypassword") }

  before do
    # Drop any existing user with the test user name
    begin
      db.users.find_by_name(test_user_name).drop
    rescue Baza::Errors::UserNotFound # rubocop:disable Lint/HandleExceptions
    end
  end

  it "Users#list" do
    root_found = false
    db.users.list do |user|
      if user.name == "root"
        root_found = true
        break
      end
    end

    expect(root_found).to eq true
  end

  it "Users#find_by_name" do
    root_user = db.users.find_by_name("root")
    expect(root_user.name).to eq "root"
  end

  it "Users#create" do
    my_user = db.users.create(name: test_user_name, host: "localhost", password: "mypassword")

    expect(my_user.name).to eq test_user_name
    expect(my_user.host).to eq "localhost"
  end

  it "User#drop" do
    user.drop
    expect { db.users.find_by_name(test_user_name) }.to raise_error(Baza::Errors::UserNotFound)
  end

  it "User#name" do
    expect(user.name).to eq test_user_name
  end

  it "User#host" do
    expect(user.host).to eq "localhost"
  end
end
