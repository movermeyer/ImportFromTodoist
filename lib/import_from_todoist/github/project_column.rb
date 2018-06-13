module ImportFromTodoist
  module Github
    class ProjectColumn < Struct.new(:id, :name)
      private_class_method :new

      def self.from_github(hash)
        new(hash.fetch('id'), hash.fetch('name'))
      end

      def self.from_name(name)
        new(nil, name)
      end

      def creation_hash
        { name: name }
      end
    end
  end
end
