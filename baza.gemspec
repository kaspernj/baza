# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = "baza"
  s.version = "0.0.7"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Kasper Johansen"]
  s.date = "2013-04-18"
  s.description = "A database abstraction layer, model framework and database framework."
  s.email = "kj@gfish.com"
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.rdoc"
  ]
  s.files = [
    ".document",
    ".rspec",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "README.rdoc",
    "Rakefile",
    "VERSION",
    "baza.gemspec",
    "include/db.rb",
    "include/dbtime.rb",
    "include/drivers/.DS_Store",
    "include/drivers/mysql/mysql.rb",
    "include/drivers/mysql/mysql_columns.rb",
    "include/drivers/mysql/mysql_indexes.rb",
    "include/drivers/mysql/mysql_sqlspecs.rb",
    "include/drivers/mysql/mysql_tables.rb",
    "include/drivers/sqlite3/libknjdb_java_sqlite3.rb",
    "include/drivers/sqlite3/libknjdb_sqlite3_ironruby.rb",
    "include/drivers/sqlite3/sqlite3.rb",
    "include/drivers/sqlite3/sqlite3_columns.rb",
    "include/drivers/sqlite3/sqlite3_indexes.rb",
    "include/drivers/sqlite3/sqlite3_sqlspecs.rb",
    "include/drivers/sqlite3/sqlite3_tables.rb",
    "include/dump.rb",
    "include/idquery.rb",
    "include/model.rb",
    "include/model_custom.rb",
    "include/model_handler.rb",
    "include/model_handler_sqlhelper.rb",
    "include/query_buffer.rb",
    "include/revision.rb",
    "include/row.rb",
    "include/sqlspecs.rb",
    "lib/baza.rb",
    "spec/baza_spec.rb",
    "spec/db_spec_encoding_test_file.txt",
    "spec/info_mysql_example.rb",
    "spec/info_sqlite3.rb",
    "spec/model_handler_spec.rb",
    "spec/spec_helper.rb"
  ]
  s.homepage = "http://github.com/kaspernj/baza"
  s.licenses = ["MIT"]
  s.require_paths = ["lib"]
  s.rubygems_version = "1.8.25"
  s.summary = "A database abstraction layer, model framework and database framework."

  if s.respond_to? :specification_version then
    s.specification_version = 3

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<datet>, [">= 0"])
      s.add_runtime_dependency(%q<wref>, [">= 0"])
      s.add_runtime_dependency(%q<knjrbfw>, [">= 0"])
      s.add_runtime_dependency(%q<array_enumerator>, [">= 0"])
      s.add_development_dependency(%q<rspec>, ["~> 2.8.0"])
      s.add_development_dependency(%q<rdoc>, ["~> 3.12"])
      s.add_development_dependency(%q<bundler>, [">= 1.0.0"])
      s.add_development_dependency(%q<jeweler>, ["~> 1.8.4"])
      s.add_development_dependency(%q<sqlite3>, [">= 0"])
      s.add_development_dependency(%q<mysql2>, [">= 0"])
    else
      s.add_dependency(%q<datet>, [">= 0"])
      s.add_dependency(%q<wref>, [">= 0"])
      s.add_dependency(%q<knjrbfw>, [">= 0"])
      s.add_dependency(%q<array_enumerator>, [">= 0"])
      s.add_dependency(%q<rspec>, ["~> 2.8.0"])
      s.add_dependency(%q<rdoc>, ["~> 3.12"])
      s.add_dependency(%q<bundler>, [">= 1.0.0"])
      s.add_dependency(%q<jeweler>, ["~> 1.8.4"])
      s.add_dependency(%q<sqlite3>, [">= 0"])
      s.add_dependency(%q<mysql2>, [">= 0"])
    end
  else
    s.add_dependency(%q<datet>, [">= 0"])
    s.add_dependency(%q<wref>, [">= 0"])
    s.add_dependency(%q<knjrbfw>, [">= 0"])
    s.add_dependency(%q<array_enumerator>, [">= 0"])
    s.add_dependency(%q<rspec>, ["~> 2.8.0"])
    s.add_dependency(%q<rdoc>, ["~> 3.12"])
    s.add_dependency(%q<bundler>, [">= 1.0.0"])
    s.add_dependency(%q<jeweler>, ["~> 1.8.4"])
    s.add_dependency(%q<sqlite3>, [">= 0"])
    s.add_dependency(%q<mysql2>, [">= 0"])
  end
end

