require "spec_helper"

shared_examples_for "a baza users driver" do
  let(:driver) { constant.new }
  let(:db) { driver.db }

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
end
