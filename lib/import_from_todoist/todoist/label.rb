module ImportFromTodoist
  module Todoist
    class Label < Struct.new(:id, :name, :color)
      private_class_method :new

      # Taken from https://developer.todoist.com/sync/v7/#labels
      TODOIST_COLORS = %w[
        019412
        a39d01
        e73d02
        e702a4
        9902e7
        1d02e7
        0082c5
        555555
        008299
        03b3b2
        ac193d
        82ba00
        111111
      ].freeze

      # Taken from the web UI. I don't know of any official definitions.
      PRIORITY_COLORS = %w[
        D30103
        FFA356
        FFD874
        FFFFFF
      ].freeze

      def self.from_todoist(hash)
        new(hash.fetch('id'), hash.fetch('name'), TODOIST_COLORS.fetch(hash.fetch('color'), TODOIST_COLORS[0]))
      end

      def self.from_priority(priority)
        new(nil,
            "Priority #{priority}",
            PRIORITY_COLORS.fetch(priority - 1,
                                  priority > PRIORITY_COLORS.length ? PRIORITY_COLORS[-1] : PRIORITY_COLORS[0]))
      end
    end
  end
end
