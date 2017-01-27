class Baza::Commands::Importer
  def initialize(args)
    @db = args.fetch(:db)
    @debug = args[:debug]
    @io = args.fetch(:io)
  end

  def execute
    sql = ""

    @io.each_line do |line|
      next if line.strip.blank?
      next if line.start_with?("--")

      debug "Add line to SQL: #{line}" if @debug
      sql << line

      next unless line.end_with?(";\n")

      debug "Execute SQL: #{sql}" if @debug
      @db.query(sql)
      sql = ""
    end
  end

private

  def debug(message)
    puts message if @debug
  end
end
