# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../../lib/import_from_todoist'

module ImportFromTodoist
  module Todoist
    class LabelTest < Minitest::Test
      def test_from_todoist_label_normal
        label = ImportFromTodoist::Todoist::Label.from_todoist(
          'id' => 1_234_567_890,
          'name' => 'Test Label',
          'color' => 5
        )
        assert_equal 1_234_567_890, label.id
        assert_equal 'Test Label', label.name
        assert_equal '1d02e7', label.color
      end

      def test_from_todoist_label_unknown_color
        label = ImportFromTodoist::Todoist::Label.from_todoist(
          'id' => 1_234_567_890,
          'name' => 'Test Label',
          'color' => 999_999_999
        )
        assert_equal 1_234_567_890, label.id
        assert_equal 'Test Label', label.name
        assert_equal '019412', label.color
      end

      def test_from_priority_normal
        label = ImportFromTodoist::Todoist::Label.from_priority(1)
        assert_equal 'Priority 1', label.name
        assert_equal 'D30103', label.color
      end

      def test_from_unexpectedly_small
        label = ImportFromTodoist::Todoist::Label.from_priority(0)
        assert_equal 'Priority 0', label.name
        assert_equal 'D30103', label.color
      end

      def test_from_unexpectedly_large
        label = ImportFromTodoist::Todoist::Label.from_priority(5)
        assert_equal 'Priority 5', label.name
        assert_equal 'FFFFFF', label.color
      end
    end
  end
end
