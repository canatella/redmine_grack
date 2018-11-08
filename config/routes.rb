require 'redmine_grack'
require 'redmine_git_lfs_s3'

class GitFlsConstraint
  def matches?(request)
    puts request.headers['Content-Type'] == 'application/vnd.git-lfs+json'
    request.headers['Content-Type'] == 'application/vnd.git-lfs+json'
  end
end

#scope :git, constraints: GitFlsConstraint.new do
#  mount Redmine::GitLfsS3::Bundle.new, as: :git_lfs
#end

class GrackLfs
  def initialize
    @grack = Redmine::Grack::Bundle.new
    @lfs = Redmine::GitLfsS3::Bundle.new
  end

  def call(env)
    @request = Rack::Request.new(env)
    if env['CONTENT_TYPE'] == 'application/vnd.git-lfs+json'
      @lfs.call(env)
    else
      @grack.call(env)
    end
  end
end

mount Redmine::GitLfsS3::Bundle.new, at: 'git/view-right.git/info/lfs'
mount Redmine::Grack::Bundle.new, at: 'git'
