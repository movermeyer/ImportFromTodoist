module ImportFromTodoist
  module Todoist
    class Label < Struct.new(:id, :name, :color)
      private_class_method :new

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

      def self.from_todoist(hash)
        new(hash.fetch('id'), hash.fetch('name'), TODOIST_COLORS.fetch(hash.fetch('color'), TODOIST_COLORS[0]))
      end
    end
  end
end
