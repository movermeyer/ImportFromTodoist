module ImportFromTodoist
  module Github
    class Label < Struct.new(:id, :name, :color)
      private_class_method :new

      def self.from_github(hash)
        new(hash.fetch('id'), hash.fetch('name'), hash.fetch('color'))
      end

      def self.from_todoist_label(label)
        new(nil, label.name, label.color)
      end

      def creation_hash
        { name: :name, color: :color }
      end

      def mutable_value_hash
        to_h.keep_if { |key, _value| !%i[id name].include? key }
      end
    end
  end
end
