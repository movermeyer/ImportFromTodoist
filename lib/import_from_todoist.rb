# frozen_string_literal: true

require 'json'

require 'rubygems'
require 'bundler/setup'
require 'faraday'

require_relative 'import_from_todoist/github/comment'
require_relative 'import_from_todoist/github/issue'
require_relative 'import_from_todoist/github/label'
require_relative 'import_from_todoist/github/milestone'
require_relative 'import_from_todoist/github/project_card'
require_relative 'import_from_todoist/github/project_column'
require_relative 'import_from_todoist/github/project'
require_relative 'import_from_todoist/github/repo'

require_relative 'import_from_todoist/todoist/api'
require_relative 'import_from_todoist/todoist/collaborator'
require_relative 'import_from_todoist/todoist/comment'
require_relative 'import_from_todoist/todoist/label'
require_relative 'import_from_todoist/todoist/project'
require_relative 'import_from_todoist/todoist/task'

require_relative 'import_from_todoist/importer'
require_relative 'import_from_todoist/system'
