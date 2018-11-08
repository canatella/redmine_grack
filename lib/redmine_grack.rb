require 'grack/app'
require 'rack/auth/basic'
require 'rack/auth/abstract/handler'
require 'rack/auth/abstract/request'
require 'benchmark'
require 'repository'

module Redmine::Grack
  module Bundle
    extend self

    def new
      Rack::Builder.new do
        use Redmine::Grack::Logger
        use Redmine::Grack::Auth
        run Redmine::Grack::App.new
      end
    end
  end

  class App < ::Grack::App
    def routes
      @routes ||= ::Grack::App::ROUTES + [[%r{/([^/]+)}, 'GET', :redirect]]
    end

    def setup_repository(request)
      # Sanitize the URI:
      # * Unescape escaped characters
      # * Replace runs of / with a single /
      path_info = Rack::Utils.unescape(request.path_info).gsub(%r{/+}, '/')

      route = routes.detect do |path_matcher, verb, handler|
        path_info.match(path_matcher) do |match|
          @repository_uri = match[1]
          @args = match[2..-1]
        end
      end
      return false if route.nil?


      @repository = ::Repository.all.detect do |r|
        r.url.match(/#{@repository_uri}\/?$/)
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

      @project = @repository.project

      return redirect if @handler == :redirect

      git.repository_path = @repository.url

      return not_found unless git.exist?

      if @env['REMOTE_USER']
        @user = User.find_by(login: @env['REMOTE_USER'])
      end

      unless @user.nil?
        Rails.logger.info("  Current user: #{@user.login} (id=#{@user.id})")
      end

      if !@project.is_public and @user.nil?
        return unauthorized
      end

      return send(@handler, *@args)
    end

    def allow_pull?
      (@project.is_public? or
       (!@user.nil? and
        @user.allowed_to?(:git_repository_pull, @project))).tap do |b|
        unless b
          Rails.logger.info("  User is not allowed to pull from #{@project.identifier}")
        end
      end
    end

    def allow_push?
      (!@user.nil? and
       @user.allowed_to?(:git_repository_push, @project)).tap do |b|
        unless b
          Rails.logger.info("  User is not allowed to push to #{@project.identifier}")
        end
      end
    end

    def redirect
      [307, { 'LOCATION' => "/projects/#{@project.identifier}" }, ['Redirected']]
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

  class Logger
    def initialize(app)
      @app = app
      @logger = Rails.logger
    end

    def call(env)
      Rails.logger.info("Processing by Redmine::Grack::App")
      response = []
      t = Benchmark.measure do
        response = @app.call(env)
      end
      status = response.first
      Rails.logger.
        info("Completed #{status} #{Rack::Utils::HTTP_STATUS_CODES[status]} in #{(t.real * 1000).round}ms")
      response
    end
  end
end
