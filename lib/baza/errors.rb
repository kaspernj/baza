class Baza::Errors
  class ColumnNotFound < RuntimeError; end
  class IndexNotFound < RuntimeError; end
  class Retry < RuntimeError; end
  class TableNotFound < RuntimeError; end
end
