# Used for link-methods in Rails apps
module Baza::DatabaseModelFunctionality
  def to_model
    Baza::DatabaseModel.new(self)
  end

  def model_name
    to_model.model_name
  end
end
