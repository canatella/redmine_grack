require 'grack/app'
require 'rack/auth/basic'
require 'rack/auth/abstract/handler'
require 'rack/auth/abstract/request'

module Redmine::Grack
  module Bundle
    extend self

    def config
      @config ||= YAML.load(File.read(Rails.root.join('config', 'grack.yml').to_s))
                    .symbolize_keys.tap do |cfg|
        cfg[:git_adapter_factory] = ->{ Grack::GitAdapter.new }
        cfg[:root] = Pathname.new(cfg[:root])
      end
    end

    def new
      Rack::Builder.new do
        use Redmine::Grack::Auth
        run Redmine::Grack::App.new(Bundle.config)
      end
    end
  end



  class App < ::Grack::App
    def setup_repository(request)
      # Sanitize the URI:
      # * Unescape escaped characters
      # * Replace runs of / with a single /
      path_info = Rack::Utils.unescape(request.path_info).gsub(%r{/+}, '/')

      route = ::Grack::App::ROUTES.detect do |path_matcher, verb, handler|
        path_info.match(path_matcher) do |match|
          @repository_uri = match[1]
          @args = match[2..-1]
        end
      end
      return false if route.nil?


      @repository = ::Repository.all.detect do |r|
        r.url.end_with?("#{@repository_uri}/")
      end
      return false if @repository.nil?

      _, @request_verb, @handler = *route

      true
    end

    # Match path against repository local url
    def route
      return not_found unless setup_repository(@request)

      return method_not_allowed unless @request_verb == request.request_method

      return bad_request if bad_uri?(@repository_uri)

      git.repository_path = @repository.url

      return not_found unless git.exist?

      @project = @repository.project
      if @env['REMOTE_USER']
        @user = User.find_by(login: @env['REMOTE_USER'])
      end

      if !@project.is_public and @user.nil?
        return unauthorized
      end

      return send(@handler, *@args)
    end

    def allow_pull?
      @project.is_public? or
        (!@user.nil? and @user.allowed_to?(:git_repository_pull, @project))
    end

    def allow_push?
      (!@user.nil? and @user.allowed_to?(:git_repository_push, @project))
    end

    def unauthorized
      [401, { 'CONTENT_TYPE' => 'text/plain',
              'CONTENT_LENGTH' => '0',
              'WWW-Authenticate' => 'Basic realm="Repository"' },
       ['Unauthorized']]
    end

  end

  class Auth < Rack::Auth::Basic
    def initialize(app, realm = nil)
      super(app, realm) do |username, password|
        # won't be used here
        false
      end
    end

    def call(env)
      @request = Rack::Request.new(env)
      @auth = Rack::Auth::Basic::Request.new(env)

      if not @auth.provided?
        return @app.call(env)
      end

      if not @auth.basic?
        return bad_request
      end

      # try to login first
      user = User.try_to_login(*@auth.credentials)
      return unauthorized if user.nil?

      # we are good to go
      env['REMOTE_USER'] = @auth.username
      @app.call(env)
    end
  end
end
