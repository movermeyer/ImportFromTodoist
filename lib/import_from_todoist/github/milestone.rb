module ImportFromTodoist
  module Github
    class Milestone < Struct.new(:id, :number, :title, :description, :state, :due_on)
      private_class_method :new

      def self.from_github(hash)
        new(hash.fetch('id'), hash.fetch('number'), hash.fetch('title'), hash.fetch('description'), hash.fetch('state'), hash.fetch('due_on'))
      end

      def self.from_due_date(date)
        new(nil, nil, date, '', 'open', date)
      end

      def creation_hash
        { title: title, state: state, description: description, due_on: due_on + 'T00:00:00Z' } # TODO: Use user's timezone
      end

      def mutable_value_hash
        to_h.keep_if { |key, _value| !%i[id number].include? key }
      end
    end
  end
end
