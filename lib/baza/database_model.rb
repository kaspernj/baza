# Used for link-methods in Rails apps
class Baza::DatabaseModel
  def initialize(instance)
    @instance = instance
  end

  def model_name
    Baza::DatabaseModelName.new(@instance)
  end

  def persisted?
    true
  end

  def to_param
    if @instance.respond_to?(:to_param)
      @instance.try(:to_param)
    else
      @instance.name
    end
  end

  def id
    @instance.name
  end
end
