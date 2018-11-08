ActionDispatch::Reloader.to_prepare do
  require_dependency 'redmine_grack'
end

Redmine::Plugin.register :redmine_grack do
  name 'Redmine Grack plugin'
  author 'Damien Merenne'
  description 'Manage access to your local git repositories over HTTP'
  version '0.0.2'
  url 'https://github.com/canatella/redmine_grack'
  author_url 'https://github.com/canatella'

  project_module :repository do
    permission :git_repository_pull, { repositories: :pull }
    permission :git_repository_push, { repositories: :push }
  end
end
