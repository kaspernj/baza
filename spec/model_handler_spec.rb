require "spec_helper"

describe "Objects" do
  let(:db_path) { "#{Dir.tmpdir}/baza_model_handler_test_#{Time.now.to_f}_#{Random.rand}.sqlite3" }
  let(:db) do
    require "sqlite3" unless RUBY_ENGINE == "jruby"
    require "tmpdir"

    File.unlink(db_path) if File.exist?(db_path)
    db = Baza::Db.new(type: :sqlite3, path: db_path, debug: false)

    schema = {
      tables: {
        "Group" => {
          columns: [
            {name: :id, type: :int, autoincr: true, primarykey: true},
            {name: :groupname, type: :varchar}
          ]
        },
        "Person" => {
          columns: [
            {name: :id, type: :int, autoincr: true, primarykey: true},
            {name: :name, type: :varchar}
          ]
        },
        "Project" => {
          columns: [
            {name: :id, type: :int, autoincr: true, primarykey: true}
          ]
        },
        "Task" => {
          columns: [
            {name: :id, type: :int, autoincr: true, primarykey: true},
            {name: :name, type: :varchar},
            {name: :person_id, type: :int},
            {name: :project_id, type: :int}
          ]
        },
        "Timelog" => {
          columns: [
            {name: :id, type: :int, autoincr: true, primarykey: true},
            {name: :person_id, type: :int}
          ]
        },
        "User" => {
          columns: [
            {name: :id, type: :int, autoincr: true, primarykey: true},
            {name: :username, type: :varchar}
          ]
        }
      }
    }
    Baza::Revision.new.init_db(schema: schema, db: db)

    db
  end

  let(:ob) do
    ob = Baza::ModelHandler.new(
      db: db,
      datarow: true,
      require: false,
      array_enum: true,
      models: {
        User: {
          cache_ids: true
        }
      }
    )

    ob.adds(:User, [
      {username: "User 1"},
      {username: "User 2"},
      {username: "User 3"},
      {username: "User 4"},
      {username: "User 5"}
    ])

    ob
  end

  let(:task) { ob.add(:Task, name: "Test task", person_id: person.id) }
  let(:person) { ob.add(:Person, name: "Kasper") }
  let(:project) { ob.add(:Project) }

  before(:all) do
    class User < Baza::Model; end

    class Project < Baza::Model
      has_many [
        {class: :Task, col: :project_id, depends: true}
      ]
    end

    class Task < Baza::Model
      has_one [
        {class: :Person, required: true},
        :Project
      ]
    end

    class Person < Baza::Model
      has_one [:Project]

      has_many [
        {class: :Timelog, autozero: true}
      ]

      def html
        self[:name]
      end
    end

    class Timelog < Baza::Model; end
  end

  it "should be able to cache rows" do
    expect(ob.ids_cache[:User].length).to eq 5

    user = ob.get(:User, 4)
    raise "No user returned." unless user
    ob.delete(user)

    expect(ob.ids_cache[:User].length).to eq 4

    ob.deletes([ob.get(:User, 1), ob.get(:User, 2)])
    expect(ob.ids_cache[:User].length).to eq 2
  end

  it "should be able to do 'select_col_as_array'" do
    res = ob.list(:User, "select_col_as_array" => "id").to_a
    expect(res.length).to eq 5
  end

  it "should work even though stressed by threads (thread-safe)." do
    userd = []
    10.upto(25) do |i|
      userd << {username: "User #{i}"}
    end

    ob.adds(:User, userd)
    users = ob.list(:User).to_a

    # Stress it to test threadsafety...
    threads = []
    0.upto(5) do |tc|
      threads << Thread.new do
        0.upto(5) do |ic|
          user = ob.add(:User, username: "User #{tc}-#{ic}")
          raise "No user returned." unless user
          ob.delete(user)

          user1 = ob.add(:User, username: "User #{tc}-#{ic}-1")
          user2 = ob.add(:User, username: "User #{tc}-#{ic}-2")
          user3 = ob.add(:User, username: "User #{tc}-#{ic}-3")

          raise "Missing user?" if !user1 || !user2 || !user3 || user1.deleted? || user2.deleted? || user3.deleted?
          ob.deletes([user1, user2, user3])

          count = 0
          users.each do |user_i|
            count += 1
            user_i[:username] = "#{user_i[:username]}." unless user_i.deleted?
          end

          expect(count).to eq 21
        end
      end
    end

    threads.each(&:join)
  end

  it "should be able to skip queries when adding" do
    class Group < Baza::Model; end

    ob2 = Baza::ModelHandler.new(
      db: db,
      datarow: true,
      require: false
    )

    threads = []
    0.upto(5) do
      threads << Thread.new do
        Thread.current.abort_on_exception = true

        0.upto(5) do
          ret = ob2.add(:Group, {groupname: "User 1"}, skip_ret: true)
          raise "Expected empty return but got something: #{ret}" if ret
        end
      end
    end

    threads.each(&:join)
  end

  it "should delete the temporary database." do
    File.unlink(db_path) if File.exist?(db_path)
  end

  # Moved from "knjrbfw_spec.rb"
  it "should be able to generate a sample SQLite database and add a sample table, with sample columns and with a sample index to it" do
    require "tmpdir"

    db_path = "#{Dir.tmpdir}/knjrbfw_test_sqlite3.sqlite3"
    db = Baza::Db.new(
      type: :sqlite3,
      path: db_path,
      index_append_table_name: true
    )

    db.tables.create(
      "Project",
      columns: [
        {name: :id, type: :int, autoincr: true, primarykey: true},
        {name: :category_id, type: :int},
        {name: :name, type: :varchar}
      ],
      indexes: [
        {name: :category_id, columns: [:category_id]}
      ]
    )

    db.tables.create(
      "Task",
      columns: [
        {name: :id, type: :int, autoincr: true, primarykey: true},
        {name: :project_id, type: :int},
        {name: :person_id, type: :int},
        {name: :name, type: :varchar}
      ],
      indexes: [
        {name: :project_id, columns: [:project_id]}
      ]
    )

    db.tables.create(
      "Person",
      columns: [
        {name: :id, type: :int, autoincr: true, primarykey: true},
        {name: :name, type: :varchar}
      ]
    )

    db.tables.create(
      "Timelog",
      columns: [
        {name: :id, type: :int, autoincr: true, primarykey: true},
        {name: :person_id, type: :int}
      ],
      indexes: [
        :person_id
      ]
    )

    table = db.tables[:Project]

    indexes = table.indexes
    raise "Could not find the sample-index 'category_id' that should have been created." unless indexes[:Project__category_id]


    # If we insert a row the ID should increase and the name should be the same as inserted (or something is very very wrong)...
    db.insert("Project", "name" => "Test project")

    count = 0
    db.q("SELECT * FROM Project") do |d|
      raise "Somehow name was not 'Test project'" if d[:name] != "Test project"
      raise "ID was not set?" if d[:id].to_i <= 0
      count += 1
    end

    raise "Expected count of 1 but it wasnt: #{count}" if count != 1
  end

  it "should be able to automatic generate methods on datarow-classes (has_many, has_one)." do
    ob = Baza::ModelHandler.new(db: db, datarow: true, require: false)

    ob.add(:Person, name: "Kasper")
    ob.add(:Task,
           name: "Test task",
           person_id: person.id,
           project_id: project.id
    )

    begin
      obb.add(:Task, name: "Test task")
      raise "Method should fail but didnt."
    rescue
      # Ignore.
    end


    # Test 'list_invalid_required'.
    db.insert(:Task, name: "Invalid require")
    id = db.last_id
    found = false

    ob.list_invalid_required(class: :Task) do |d|
      raise "Expected object ID to be #{id} but it wasnt: #{d[:obj].id}" if d[:obj].id.to_i != id.to_i
      ob.delete(d[:obj])
      found = true
    end

    raise "Expected to find a task but didnt." unless found


    ret_proc = []
    ob.list(:Task) do |task|
      ret_proc << task
    end

    raise "list with proc should return one task but didnt." if ret_proc.length != 1


    tasks = project.tasks
    raise "No tasks were found on project?" if tasks.empty?


    ret_proc = []
    ret_test = project.tasks do |task|
      ret_proc << task
    end

    raise "When given a block the return should be nil so it doesnt hold weak-ref-objects in memory but it didnt return nil." unless ret_test == nil
    raise "list for project with proc should return one task but didnt (#{ret_proc.length})." if ret_proc.length != 1

    person = tasks.first.person
    project_second = tasks.first.project

    raise "Returned object was not a person on task." unless person.is_a?(Person)
    raise "Returned object was not a project on task." unless project_second.is_a?(Project)


    # Check that has_many-depending is actually working.
    begin
      ob.delete(project)
      raise "It was possible to delete project 1 even though task 1 depended on it!"
    rescue
      # This should happen - it should not possible to delete project 1 because task 1 depends on it."
    end
  end

  it "should be able to generate lists for inputs" do
    task
    list = ob.list_optshash(:Task)
    list.length.should eq 1
    list[1].should eq "Test task"
  end

  it "should be able to connect to objects 'no-html' callback and test it." do
    task
    ob.events.connect(:no_html) do |_event, classname|
      "[no #{classname.to_s.downcase}]"
    end

    expect(task.person_html).to eq "Kasper"
    task.update(person_id: 0)
    expect(task.person_html).to eq "[no person]"
  end

  it "should be able to to multiple additions and delete objects through a buffer" do
    objs = []
    0.upto(500) do
      objs << {name: :Kasper}
    end

    ob.adds(:Person, objs)
    pers_length = ob.list(:Person, "count" => true)

    count = 0
    db.q_buffer do |buffer|
      ob.list(:Person) do |person|
        count += 1
        ob.delete(person, db_buffer: buffer)
      end

      buffer.flush
    end

    raise "Expected count to be #{pers_length} but it wasnt: #{count}" if count != pers_length

    persons = ob.list(:Person).to_a
    raise "Expected persons count to be 0 but it wasnt: #{persons.map(&:data)}" if persons.length > 0
  end

  it "should do autozero when deleting objects" do
    person1 = ob.add(:Person, name: "Kasper")
    person2 = ob.add(:Person, name: "Charlotte")

    timelog1 = ob.add(:Timelog, person_id: person1.id)
    timelog2 = ob.add(:Timelog, person_id: person2.id)

    ob.delete(person1)

    raise "Expected timelog1's person-ID to be zero but it wasnt: '#{timelog1[:person_id]}'." if timelog1[:person_id].to_i != 0
    raise "Expected timelog2's person-ID to be #{person2.id} but it wasnt: '#{timelog2[:person_id]}'." if timelog2[:person_id].to_i != person2.id.to_i
  end

  it "should be able to do multiple deletes from ids" do
    ids = []
    1.upto(10) do |_count|
      ids << ob.add(:Person).id
    end

    ob.delete_ids(class: :Person, ids: ids)
  end

  it "get_or_add" do
    person1 = ob.add(:Person, name: "get_or_add")
    person2 = ob.get_or_add(:Person, name: "get_or_add")

    person2.id.should eql(person1.id)
    person2[:name].should eql("get_or_add")

    person3 = ob.get_or_add(:Person, name: "get_or_add3")

    raise "Failure ID was the same" if person3.id == person2.id
    person3[:name].should eql("get_or_add3")
  end

  it "should delete the temp database again." do
    require "tmpdir"
    db_path = "#{Dir.tmpdir}/knjrbfw_test_sqlite3.sqlite3"
    File.unlink(db_path) if File.exist?(db_path)
  end
end
