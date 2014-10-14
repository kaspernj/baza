[![Code Climate](https://codeclimate.com/github/kaspernj/baza/badges/gpa.svg)](https://codeclimate.com/github/kaspernj/baza)
[![Test Coverage](https://codeclimate.com/github/kaspernj/baza/badges/coverage.svg)](https://codeclimate.com/github/kaspernj/baza)
[![Build Status](https://api.shippable.com/projects/540e7b993479c5ea8f9ec1fe/badge?branchName=master)](https://app.shippable.com/projects/540e7b993479c5ea8f9ec1fe/builds/latest)

# baza

A database abstraction layer for Ruby.

## Installation

Is fairly painless.
  gem install baza

## Connection to a database.

### MySQL
```ruby
db = Baza::Db.new(:type => :mysql, :subtype => :mysql2, :host => "localhost", :user => "my_user", :pass => "my_password", :port => 3306, :db => "my_database")
```

### SQLite3
```ruby
db = Baza::Db.new(:type => :sqlite3, :path => "/path/to/file.sqlite3")
```

## Queries

### Select
```ruby
db.select(:users, {:name => "Kasper"}, {:orderby => "age"}) do |row|
  puts "Row: #{row}"
end

name = "Kasper"
db.q("SELECT * FROM users WHERE name = '#{db.esc(name)}' ORDER BY age") do |row|
  puts "Row: #{row}"
end
```

### Inserting
```ruby
db.insert(:users, {:name => "Kasper", :age => 27})
id = db.last_id
```

It can also return the ID at the same time
```ruby
id = db.insert(:users, {:name => "Kasper", :age => 27}, :return_id => true)
```

Inserting multiple rows in one query is also fairly painless:
```ruby
db.insert_multi(:users, [
  {:name => "Kasper", :age => 27},
  {:name => "Christina", :age => 25},
  {:name => "Charlotte", :age => 23}
])
```

### Update
```ruby
db.update(:users, {:name => "Kasper Johansen"}, {:name => "Kasper"})
```

### Delete
```ruby
db.delete(:users, {:name => "Kasper"})
```

### Upsert
The following example handels a row that will be inserted with {:name => "Kasper", :age => 27} if it doesnt exist or rows with {:name => "Kasper"} will have their their age updated to 27.
```ruby
db.upsert(:users, {:name => "Kasper"}, {:age => 27})
```

## Structure

### Table creation
```ruby
db.tables.create(:users, {
  :columns => [
    {:name => :id, :type => :int, :autoincr => true, :primarykey => true},
    {:name => :name, :type => :varchar}
  ],
  :indexes => [
    :name
  ]
})
```

### Table dropping
```ruby
table = db.tables[:users]
table.drop
```

### Table listing
```ruby
array_of_tables = db.tables.list
```

Or you can use blocks:
```ruby
db.tables.list do |table|
  puts "Table-name: #{table.name}"
end
```

### Table renaming
```ruby
table = db.tables[:users]
table.rename(:new_table_name)
```

### Column listing
```ruby
table = db.tables[:users]
cols = table.columns
```

Or a specific column:
```ruby
col = table.column(:id)
puts "Column: #{col.name} #{col.type}(#{col.maxlength})"
```

## Copying databases
```ruby
db_mysql = Baza::Db.new(:type => :mysql, :subtype => :mysql2, ...)
db_sqlite = Baza::Db.new(:type => :sqlite3, :path => ...)

db_mysql.copy_to(db_sqlite)
```

## Dumping SQL to an IO
```ruby
db = Baza::Db.new(...)
dump = Baza::Dump.new(:db => db)
str_io = StringIO.new
dump.dump(str_io)
```

## Transactions
```ruby
db.transaction do
  1000.times do
    db.insert(:users, {:name => "Kasper"})
  end
end
```

## Query Buffer
In order to speed things up, but without using transactions directly, you can use a query buffer. This stores various instructions in memory and flushes them every now and then through transactions or intelligent queries (like multi-insertion). The drawback is that it will not be possible to test the queries for errors before a flush is executed and it wont be possible to read results form any of the queries. It is fairly simple do however:
```ruby
db.q_buffer do |buffer|
  100_000.times do |count|
    buffer.insert(:table_name, {:name => "Kasper #{count}"})

    buffer.query("UPDATE table SET ...")
    buffer.query("DELETE FROM table WHERE ...")
  end
end
```

## Contributing to baza
 
* Check out the latest master to make sure the feature hasn't been implemented or the bug hasn't been fixed yet.
* Check out the issue tracker to make sure someone already hasn't requested it and/or contributed it.
* Fork the project.
* Start a feature/bugfix branch.
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.
* Please try not to mess with the Rakefile, version, or history. If you want to have your own version, or is otherwise necessary, that is fine, but please isolate to its own commit so I can cherry-pick around it.

## Copyright

Copyright (c) 2013 Kasper Johansen. See LICENSE.txt for
further details.

