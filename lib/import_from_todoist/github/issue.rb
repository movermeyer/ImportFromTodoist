# frozen_string_literal: true

module ImportFromTodoist
  module Github
    class Issue < Struct.new(:id, :number, :title, :state, :body, :milestone_number, :label_names)
      private_class_method :new

      def self.from_github(hash)
        milestone_hash = hash.fetch('milestone')
        milestone_number = milestone_hash ? ImportFromTodoist::Github::Milestone.from_github(milestone_hash).number : nil
        labels = hash.fetch('labels', []).map { |label_hash| ImportFromTodoist::Github::Label.from_github(label_hash).name }
        new(hash.fetch('id'), hash.fetch('number'), hash.fetch('title'), hash.fetch('state'), hash.fetch('body'), milestone_number, labels.sort)
      end

      def self.from_hash(hash)
        new(nil, nil, hash.fetch(:title), hash.fetch(:state), hash.fetch(:body), hash[:milestone_number], hash.fetch(:labels, []).sort)
      end

      def creation_hash
        hash = { title: title, state: state, body: body }
        hash[:milestone] = milestone_number if milestone_number
        hash[:labels] = label_names unless label_names.empty?
        hash
      end

      def mutable_value_hash
        creation_hash
      end
    end
  end
end
