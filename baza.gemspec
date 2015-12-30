# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run 'rake gemspec'
# -*- encoding: utf-8 -*-
# stub: baza 0.0.20 ruby lib

Gem::Specification.new do |s|
  s.name = "baza"
  s.version = "0.0.20"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib"]
  s.authors = ["Kasper Johansen"]
  s.date = "2015-12-30"
  s.description = "A database abstraction layer, model framework and database framework."
  s.email = "kj@gfish.com"
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = [
    ".document",
    ".rspec",
    ".rubocop_todo.yml",
    "Gemfile",
    "Gemfile.lock",
    "LICENSE.txt",
    "README.md",
    "Rakefile",
    "VERSION",
    "baza.gemspec",
    "config/best_project_practice_rubocop.yml",
    "config/best_project_practice_rubocop_todo.yml",
    "lib/baza.rb",
    "lib/baza/base_sql_driver.rb",
    "lib/baza/cloner.rb",
    "lib/baza/column.rb",
    "lib/baza/database.rb",
    "lib/baza/database_model.rb",
    "lib/baza/database_model_functionality.rb",
    "lib/baza/database_model_name.rb",
    "lib/baza/db.rb",
    "lib/baza/dbtime.rb",
    "lib/baza/driver.rb",
    "lib/baza/drivers/active_record.rb",
    "lib/baza/drivers/active_record/columns.rb",
    "lib/baza/drivers/active_record/indexes.rb",
    "lib/baza/drivers/active_record/result.rb",
    "lib/baza/drivers/active_record/tables.rb",
    "lib/baza/drivers/mysql.rb",
    "lib/baza/drivers/mysql/column.rb",
    "lib/baza/drivers/mysql/columns.rb",
    "lib/baza/drivers/mysql/database.rb",
    "lib/baza/drivers/mysql/databases.rb",
    "lib/baza/drivers/mysql/index.rb",
    "lib/baza/drivers/mysql/indexes.rb",
    "lib/baza/drivers/mysql/result.rb",
    "lib/baza/drivers/mysql/sqlspecs.rb",
    "lib/baza/drivers/mysql/table.rb",
    "lib/baza/drivers/mysql/tables.rb",
    "lib/baza/drivers/mysql/unbuffered_result.rb",
    "lib/baza/drivers/mysql2.rb",
    "lib/baza/drivers/mysql2/column.rb",
    "lib/baza/drivers/mysql2/columns.rb",
    "lib/baza/drivers/mysql2/database.rb",
    "lib/baza/drivers/mysql2/databases.rb",
    "lib/baza/drivers/mysql2/index.rb",
    "lib/baza/drivers/mysql2/indexes.rb",
    "lib/baza/drivers/mysql2/result.rb",
    "lib/baza/drivers/mysql2/table.rb",
    "lib/baza/drivers/mysql2/tables.rb",
    "lib/baza/drivers/mysql_java.rb",
    "lib/baza/drivers/mysql_java/column.rb",
    "lib/baza/drivers/mysql_java/columns.rb",
    "lib/baza/drivers/mysql_java/database.rb",
    "lib/baza/drivers/mysql_java/databases.rb",
    "lib/baza/drivers/mysql_java/index.rb",
    "lib/baza/drivers/mysql_java/indexes.rb",
    "lib/baza/drivers/mysql_java/table.rb",
    "lib/baza/drivers/mysql_java/tables.rb",
    "lib/baza/drivers/sqlite3.rb",
    "lib/baza/drivers/sqlite3/column.rb",
    "lib/baza/drivers/sqlite3/columns.rb",
    "lib/baza/drivers/sqlite3/database.rb",
    "lib/baza/drivers/sqlite3/databases.rb",
    "lib/baza/drivers/sqlite3/index.rb",
    "lib/baza/drivers/sqlite3/indexes.rb",
    "lib/baza/drivers/sqlite3/result.rb",
    "lib/baza/drivers/sqlite3/sqlspecs.rb",
    "lib/baza/drivers/sqlite3/table.rb",
    "lib/baza/drivers/sqlite3/tables.rb",
    "lib/baza/drivers/sqlite3/unbuffered_result.rb",
    "lib/baza/drivers/sqlite3_java.rb",
    "lib/baza/drivers/sqlite3_java/column.rb",
    "lib/baza/drivers/sqlite3_java/columns.rb",
    "lib/baza/drivers/sqlite3_java/database.rb",
    "lib/baza/drivers/sqlite3_java/index.rb",
    "lib/baza/drivers/sqlite3_java/indexes.rb",
    "lib/baza/drivers/sqlite3_java/table.rb",
    "lib/baza/drivers/sqlite3_java/tables.rb",
    "lib/baza/drivers/sqlite3_java/unbuffered_result.rb",
    "lib/baza/drivers/sqlite3_rhodes.rb",
    "lib/baza/dump.rb",
    "lib/baza/errors.rb",
    "lib/baza/idquery.rb",
    "lib/baza/index.rb",
    "lib/baza/jdbc_driver.rb",
    "lib/baza/jdbc_result.rb",
    "lib/baza/model.rb",
    "lib/baza/model_custom.rb",
    "lib/baza/model_handler.rb",
    "lib/baza/model_handler_sqlhelper.rb",
    "lib/baza/mysql_base_driver.rb",
    "lib/baza/query_buffer.rb",
    "lib/baza/result_base.rb",
    "lib/baza/revision.rb",
    "lib/baza/row.rb",
    "lib/baza/sqlspecs.rb",
    "lib/baza/table.rb",
    "shippable.yml",
    "spec/cloner_spec.rb",
    "spec/drivers/active_record_mysql2_spec.rb",
    "spec/drivers/active_record_mysql_spec.rb",
    "spec/drivers/active_record_sqlite3_spec.rb",
    "spec/drivers/mysql2_spec.rb",
    "spec/drivers/mysql_spec.rb",
    "spec/drivers/sqlite3_spec.rb",
    "spec/info_active_record_example.rb",
    "spec/info_active_record_mysql.rb",
    "spec/info_active_record_mysql2.rb",
    "spec/info_active_record_mysql2_shippable.rb",
    "spec/info_active_record_mysql_shippable.rb",
    "spec/info_active_record_sqlite3.rb",
    "spec/info_mysql2_example.rb",
    "spec/info_mysql2_shippable.rb",
    "spec/info_mysql_example.rb",
    "spec/info_mysql_shippable.rb",
    "spec/info_sqlite3.rb",
    "spec/model_handler_spec.rb",
    "spec/spec_helper.rb",
    "spec/support/driver_collection.rb",
    "spec/support/driver_columns_collection.rb",
    "spec/support/driver_databases_collection.rb",
    "spec/support/driver_indexes_collection.rb",
    "spec/support/driver_tables_collection.rb"
  ]
  s.homepage = "http://github.com/kaspernj/baza"
  s.licenses = ["MIT"]
  s.rubygems_version = "2.4.0"
  s.summary = "A database abstraction layer, model framework and database framework."

  if s.respond_to? :specification_version then
    s.specification_version = 4

    if Gem::Version.new(Gem::VERSION) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<datet>, ["~> 0.0.25"])
      s.add_runtime_dependency(%q<wref>, ["~> 0.0.8"])
      s.add_runtime_dependency(%q<array_enumerator>, ["~> 0.0.10"])
      s.add_runtime_dependency(%q<string-cases>, ["~> 0.0.1"])
      s.add_runtime_dependency(%q<event_handler>, ["~> 0.0.0"])
      s.add_development_dependency(%q<rspec>, [">= 0"])
      s.add_development_dependency(%q<rdoc>, [">= 0"])
      s.add_development_dependency(%q<bundler>, [">= 0"])
      s.add_development_dependency(%q<jeweler>, [">= 0"])
      s.add_development_dependency(%q<pry>, [">= 0"])
      s.add_development_dependency(%q<jdbc-sqlite3>, [">= 0"])
      s.add_development_dependency(%q<jdbc-mysql>, [">= 0"])
      s.add_development_dependency(%q<activerecord-jdbc-adapter>, [">= 0"])
      s.add_development_dependency(%q<sqlite3>, [">= 0"])
      s.add_development_dependency(%q<mysql>, [">= 0"])
      s.add_development_dependency(%q<mysql2>, [">= 0"])
      s.add_development_dependency(%q<activerecord>, ["= 4.2.5"])
      s.add_development_dependency(%q<best_practice_project>, [">= 0"])
      s.add_development_dependency(%q<rubocop>, ["= 0.35.1"])
    else
      s.add_dependency(%q<datet>, ["~> 0.0.25"])
      s.add_dependency(%q<wref>, ["~> 0.0.8"])
      s.add_dependency(%q<array_enumerator>, ["~> 0.0.10"])
      s.add_dependency(%q<string-cases>, ["~> 0.0.1"])
      s.add_dependency(%q<event_handler>, ["~> 0.0.0"])
      s.add_dependency(%q<rspec>, [">= 0"])
      s.add_dependency(%q<rdoc>, [">= 0"])
      s.add_dependency(%q<bundler>, [">= 0"])
      s.add_dependency(%q<jeweler>, [">= 0"])
      s.add_dependency(%q<pry>, [">= 0"])
      s.add_dependency(%q<jdbc-sqlite3>, [">= 0"])
      s.add_dependency(%q<jdbc-mysql>, [">= 0"])
      s.add_dependency(%q<activerecord-jdbc-adapter>, [">= 0"])
      s.add_dependency(%q<sqlite3>, [">= 0"])
      s.add_dependency(%q<mysql>, [">= 0"])
      s.add_dependency(%q<mysql2>, [">= 0"])
      s.add_dependency(%q<activerecord>, ["= 4.2.5"])
      s.add_dependency(%q<best_practice_project>, [">= 0"])
      s.add_dependency(%q<rubocop>, ["= 0.35.1"])
    end
  else
    s.add_dependency(%q<datet>, ["~> 0.0.25"])
    s.add_dependency(%q<wref>, ["~> 0.0.8"])
    s.add_dependency(%q<array_enumerator>, ["~> 0.0.10"])
    s.add_dependency(%q<string-cases>, ["~> 0.0.1"])
    s.add_dependency(%q<event_handler>, ["~> 0.0.0"])
    s.add_dependency(%q<rspec>, [">= 0"])
    s.add_dependency(%q<rdoc>, [">= 0"])
    s.add_dependency(%q<bundler>, [">= 0"])
    s.add_dependency(%q<jeweler>, [">= 0"])
    s.add_dependency(%q<pry>, [">= 0"])
    s.add_dependency(%q<jdbc-sqlite3>, [">= 0"])
    s.add_dependency(%q<jdbc-mysql>, [">= 0"])
    s.add_dependency(%q<activerecord-jdbc-adapter>, [">= 0"])
    s.add_dependency(%q<sqlite3>, [">= 0"])
    s.add_dependency(%q<mysql>, [">= 0"])
    s.add_dependency(%q<mysql2>, [">= 0"])
    s.add_dependency(%q<activerecord>, ["= 4.2.5"])
    s.add_dependency(%q<best_practice_project>, [">= 0"])
    s.add_dependency(%q<rubocop>, ["= 0.35.1"])
  end
end

