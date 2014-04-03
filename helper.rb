require_relative 'colorize.rb' # from the 'colorize' gem

module Logger
  # some debugging tags ~ see the log method
  DEBUG_TAGS = [:debug, :info, :warn, :error, :fatal,  :unknown]

  # only messages of the debug level and above will be displayed
  DEBUG_LVL = 1 # :debug, :info, :warn, :error, :fatal, and :unknown (0 - 5)

  #############################################################################
  # displays the log message if the debug level is set to show it.
  # level - must be one of the DEBUG_TAGS
  #############################################################################
  def log(message, level)
    if DEBUG_TAGS.index(level) >= DEBUG_LVL && DEBUG_TAGS.include?(level)
      tag = '[' +
        level.to_s.upcase.colorize(color: :white, background: :black) + '] '
      puts tag + message
    end
  end
end
