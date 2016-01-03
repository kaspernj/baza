# Subclass that contains all the drivers as further subclasses.
class Baza::Driver
  AutoAutoloader.autoload_sub_classes(self, __FILE__)
end
