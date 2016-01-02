class Baza::Errors
  class DatabaseNotFound < RuntimeError; end
  class ColumnNotFound < RuntimeError; end
  class IndexNotFound < RuntimeError; end
  class NotImplemented < RuntimeError; end
  class Retry < RuntimeError; end
  class TableNotFound < RuntimeError; end
  class RowNotFound < RuntimeError; end
end
