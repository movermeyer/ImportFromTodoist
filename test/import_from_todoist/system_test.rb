require 'minitest/autorun'
require_relative '../../lib/import_from_todoist'

# Mock out the GitHub API


module ImportFromTodoist
  class SystemTest < Minitest::Test
    def setup
      @github_api = Minitest::Mock.new
      @github_api.expect :issues, []
      @github_api.expect :projects, []
      @github_api.expect :milestones, []
      @github_api.expect :comments, []

      @todoist_api = Minitest::Mock.new
    end

    def teardown
      @github_api.verify
      @todoist_api.verify
    end

    def test_sync_label_no_existing_label
      system = System.new(@todoist_api, @github_api)
      label = ImportFromTodoist::Todoist::Label.send(:new, '123', 'Test Label', '555555')
      desired_github_label = ImportFromTodoist::Github::Label.from_todoist_label(label)
      
      @github_api.expect :label, nil, ['Test Label']
      @github_api.expect :create_label, desired_github_label, [desired_github_label]
      @github_api.expect :update_label, desired_github_label, [desired_github_label, {}]
      assert_equal desired_github_label, system.sync_label(label)
    end
  end
end