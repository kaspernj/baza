# Used for link-methods in Rails apps
class Baza::DatabaseModelName
  def initialize(instance)
    @instance = instance
  end

  def singular_route_key
    route_key = human.underscore
    route_key = "indexes" if route_key == "indices"
    route_key
  end

  def human
    @instance.class.name.split("::").last
  end
end
