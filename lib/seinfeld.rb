require 'rubygems'
require 'bundler/setup'

dir = File.dirname(__FILE__)
$LOAD_PATH.unshift File.expand_path(dir)

require 'erb'
require 'logger'
require 'active_record'
require 'fileutils'

# Gives all the AR models their own tablenamespace:
#
#   seinfeld_*
#
class Seinfeld < ActiveRecord::Base
  class << self
    # String pointer to the root directory of the app.
    attr_accessor :root

    # ActiveSupport::StringInquirer instance of the current environment.  Set
    # by RACK_ENV or RAILS_ENV.
    attr_reader :env

    # String path to the database.yml
    attr_accessor :db_config_path

    # String path to the location of the log directory.
    attr_accessor :log_path

    attr_accessor :logger

    # Hash options for GitHub OAuth
    # :client_id - String OAuth2 Client ID hash.
    # :secret    - String OAuth2 Secret hash.
    attr_accessor :oauth
  end

  self.oauth = {
    :site              => ENV['OAUTH_SITE'] || "https://github.com",
    :authorize_path    => "/login/oauth/authorize",
    :access_token_path => "/login/oauth/access_token",
    :client_id         => ENV['OAUTH_CLIENT_ID'],
    :secret            => ENV['OAUTH_SECRET']}

  [:App, :User, :Progression, :Feed, :Streak, :CalendarHelper, :Updater].each do |const|
    autoload const, "seinfeld/#{const.to_s.underscore}"
  end

  def self.env=(v)
    @env = ActiveSupport::StringInquirer.new(v || 'development')
  end

  def self.log_to(path)
    self.log_path = path
    file = path_from_root(log_path)
    FileUtils.mkdir_p File.dirname(file)
    ActiveRecord::Base.logger = self.logger = Logger.new(file)
  end

  # Public: Reads the database.yml config and starts up the connection to the
  # database.
  #
  # Returns nothing.
  def self.configure(new_env = nil)
    self.env = new_env if new_env
    Time.zone = "UTC"
    path = path_from_root(db_config_path)
    yaml = ERB.new(IO.read(path)).result
    data = YAML.load(yaml)
    ActiveRecord::Base.establish_connection data[env.to_s]
    log_to "log/#{Seinfeld.env}.log"
  end

  # Either joins the given path with the Seinfeld.root as a base, or returns
  # the absolute path.
  #
  # path - Relative or absolute String path.
  #
  # Returns absolute String path.
  def self.path_from_root(path)
    path =~ /^\// ? path : File.join(root, path)
  end
end

Seinfeld.root           = File.expand_path(File.join(dir, '..'))
Seinfeld.env            = ENV['RACK_ENV'] || ENV['RAILS_ENV']
Seinfeld.db_config_path = 'config/database.yml'
