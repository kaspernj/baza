Gem::Specification.new do |s|
  s.name = "baza".freeze
  s.version = "0.0.38"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Kasper Johansen".freeze]
  s.date = "2021-10-04"
  s.description = "A database abstraction layer, model framework and database framework.".freeze
  s.email = "kj@gfish.com".freeze
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = Dir["{include,lib}/**/*"] + ["Rakefile"]
  s.test_files = Dir["spec/**/*"]
  s.homepage = "http://github.com/kaspernj/baza".freeze
  s.licenses = ["MIT".freeze]
  s.rubygems_version = "3.1.6".freeze
  s.summary = "A database abstraction layer, model framework and database framework.".freeze

  s.add_dependency("array_enumerator", ">= 0.0.10")
  s.add_dependency("auto_autoloader", ">= 0.0.5")
  s.add_dependency("datet", ">= 0.0.25")
  s.add_dependency("event_handler", ">= 0.0.0")
  s.add_dependency("simple_delegate", ">= 0.0.2")
  s.add_dependency("string-cases", ">= 0.0.4")
  s.add_dependency("wref", ">= 0.0.8")

  s.add_development_dependency("activerecord", "6.1.6")
  s.add_development_dependency("best_practice_project", ">= 0.0.9")
  s.add_development_dependency("bundler", ">= 0")
  s.add_development_dependency("pry", ">= 0")
  s.add_development_dependency("rake")
  s.add_development_dependency("rdoc", ">= 0")
  s.add_development_dependency("rspec", ">= 3.4.0")
  s.add_development_dependency("rubocop")
  s.add_development_dependency("rubocop-rspec")

  if RUBY_PLATFORM == "java"
    s.add_development_dependency("activerecord-jdbc-adapter")
    s.add_development_dependency("jdbc-mysql", ">= 0")
    s.add_development_dependency("jdbc-sqlite3", ">= 0")
  else
    s.add_development_dependency("mysql2", ">= 0.4.10")
    s.add_development_dependency("pg", ">= 1.3.5")
    s.add_development_dependency("sqlite3", ">= 1.4.2")
  end
end
