require 'time'
require 'yajl'
require 'faraday'

class Seinfeld
  class Feed
    class << self
      attr_accessor :user_agent
      attr_writer   :connection
    end
    self.user_agent = 'Calendar About Nothing: https://github.com/technoweenie/seinfeld'

    # A Array of Hashes of the parsed event JSON.
    attr_reader :items

    # The String GitHub account name.
    attr_reader :login

    # The String url that the atom feed was fetched from (default: :direct)
    attr_reader :url

    # Returned ETag from the response.
    attr_accessor :etag

    def self.connection
      @connection ||= begin
        options = {:headers => {'User-Agent' => user_agent}}
        Faraday::Connection.new(options) do |builder|
          builder.adapter :typhoeus
        end
      end
    end

    # Public: Downloads a user's public feed from GitHub.
    #
    # login - String login name from GitHub.
    #
    # Returns Seinfeld::Feed instance.
    def self.fetch(login, page = nil)
      user = login.is_a?(User) ? login : User.new(:login => login.to_s)
      url = "https://api.github.com/users/#{user.login}/events"
      resp = connection.get url do |req|
        req.headers['If-None-Match'] = user.etag
        req.params['page'] = (page || 1).to_s
      end
      new(login, resp, url)
    end

    # Parses the given data with Yajl.
    #
    # login - String login of the user being scanned.
    # data  - String JSON data.
    # url   - String url that was used.  (default: :direct)
    #
    # Returns Seinfeld::Feed.
    def initialize(login, data, url = nil)
      @url ||= :direct
      @disabled = false
      @login = login.to_s
      if data.respond_to?(:body)
        if !(data.success? || data.status == 304)
          @disabled = true
          @items = []
          return
        end

        @etag = data.headers['etag']
        data = data.body.to_s
      else
        data = data.to_s
      end
      @items = parse(data)
    end

    # Public: Scans the parsed atom entries and pulls out all committed days.
    #
    # Returns Array of unique Date objects.
    def committed_days
      @committed_days ||= begin
        days = []
        items.each do |item|
          self.class.committed?(item) && 
            days << Time.zone.parse(item['created_at']).to_date
        end
        days.uniq!
        days
      end
    end

    VALID_EVENTS = %w(PushEvent CommitEvent ForkApplyEvent)

    # Determines whether the given entry counts as a commit or not.
    #
    # item - Hash containing the data for one event.
    #
    # Returns true if the entry is a commit, and false if it isn't.
    def self.committed?(item)
      type = item['type']
      return true if VALID_EVENTS.include?(type)
      if type == 'CreateEvent'
        payload = item['payload']
        return true if payload && (payload['ref_type'] || payload['object']) == 'branch'
        return true if item['url'].to_s =~ %r[/compare/]
      end

      false
    end

    def disabled?
      @disabled
    end

    def inspect
      %(#<Seinfeld::Feed:#{@url} (#{items.size})>)
    end

    def parse(json)
      Yajl::Parser.parse(json) || []
    rescue Yajl::ParseError, Faraday::Error::ClientError
      # TODO: Raise Seinfeld::Feed::Error instead
      if $!.message =~ /404/
        @disabled = true
      end
      []
    end
  end
end
