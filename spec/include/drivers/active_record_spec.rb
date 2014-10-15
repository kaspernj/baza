require "spec_helper"

describe Baza::Driver::ActiveRecord do
  it_behaves_like "a baza driver"
  it_should_behave_like "a baza tables driver"
  it_should_behave_like "a baza columns driver"
  it_should_behave_like "a baza indexes driver"
end