Gem::Specification.new do |s|
  s.name = "baza".freeze
  s.version = "0.0.38"

  s.required_rubygems_version = Gem::Requirement.new(">= 0".freeze) if s.respond_to? :required_rubygems_version=
  s.require_paths = ["lib".freeze]
  s.authors = ["Kasper Stöckel".freeze]
  s.description = "A database abstraction layer, model framework and database framework.".freeze
  s.email = "kj@gfish.com".freeze
  s.extra_rdoc_files = [
    "LICENSE.txt",
    "README.md"
  ]
  s.files = Dir["{include,lib}/**/*"] + ["Rakefile"]
  s.homepage = "http://github.com/kaspernj/baza".freeze
  s.licenses = ["MIT".freeze]
  s.summary = "A database abstraction layer, model framework and database framework.".freeze

  s.add_dependency("array_enumerator", ">= 0.0.10")
  s.add_dependency("auto_autoloader", ">= 0.0.5")
  s.add_dependency("datet", ">= 0.0.25")
  s.add_dependency("event_handler", ">= 0.0.0")
  s.add_dependency("simple_delegate", ">= 0.0.2")
  s.add_dependency("string-cases", ">= 0.0.4")
  s.add_dependency("wref", ">= 0.0.8")
end
