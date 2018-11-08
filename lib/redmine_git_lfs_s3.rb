require "git-lfs-s3"

module Redmine::GitLfsS3
  module Bundle
    extend self

    def options
      return @options unless @options.nil?
      @options = {}.tap do |options|
        file = ERB.new( File.read(File.join(Rails.root, 'config', 's3.yml')) ).result
        YAML::load( file )[Rails.env].each do |key, value|
          options[key.to_sym] = value
        end
      end
    end

    def new
      GitLfsS3::Application.set :aws_region, options[:region]
      GitLfsS3::Application.set :aws_access_key_id, options[:access_key_id]
      GitLfsS3::Application.set :aws_secret_access_key, options[:secret_access_key]
      GitLfsS3::Application.set :s3_bucket, options[:bucket]
      GitLfsS3::Application.set :public_server, false
      GitLfsS3::Application.set :server_url, File.join(options[:url], 'git',
                                                       'view-right.git', 'info',
                                                       'lfs')
      GitLfsS3::Application.set :logger, Rails.logger

      GitLfsS3::Application.on_authenticate do |username, password|
        !User.try_to_login(username, password).nil?
      end

      Rack::Builder.new do
        run GitLfsS3::Application.new
      end
    end
  end
end
