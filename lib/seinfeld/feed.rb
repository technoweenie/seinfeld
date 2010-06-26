require 'time'
require 'yajl'
require 'faraday'

class Seinfeld
  class Feed
    class << self
      attr_accessor :user_agent
      attr_writer   :connection
    end
    self.user_agent = 'Calendar About Nothing: http://github.com/technoweenie/seinfeld'

    # A Array of Hashes of the parsed event JSON.
    attr_reader :items

    # The String GitHub account name.
    attr_reader :login

    # The String url that the atom feed was fetched from (default: :direct)
    attr_reader :url

    # Returned ETag from the response.
    attr_accessor :etag

    def self.connection
      @connection ||= Faraday::Connection.new(
          :headers => {'User-Agent' => user_agent}
        ) do |b|
          b.adapter :typhoeus
      end
    end

    # Public: Downloads a user's public feed from GitHub.
    #
    # login - String login name from GitHub.
    # 
    # Returns Seinfeld::Feed instance.
    def self.fetch(login)
      user = login.is_a?(User) ? login : User.new(:login => login.to_s)
      url  = "http://github.com/#{user.login}.json"
      resp = connection.get(url, 'If-None-Match' => user.etag)
      new(login, resp, url)
    rescue Yajl::ParseError, Faraday::Error::ClientError
      # TODO: Raise Seinfeld::Feed::Error instead
      if $!.message =~ /404/
        nil # the user is missing, disable them
      else
        # some other error?
        new(login, "[]", url)
      end
    end

    # Parses the given data with Yajl.
    #
    # login - String login of the user being scanned.
    # data  - String JSON data.
    # url   - String url that was used.  (default: :direct)
    #
    # Returns Seinfeld::Feed.
    def initialize(login, data, url = nil)
      @login = login.to_s
      if data.respond_to?(:body)
        @etag = data.headers['etag']
        data  = data.body.to_s
      else
        data = data.to_s
      end
      @url ||= :direct
      @items = Yajl::Parser.parse(data) || []
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
      VALID_EVENTS.include?(type) || (
        type == 'CreateEvent' && item['payload'] && item['payload']['object'] == 'branch')
    end

    def inspect
      %(#<Seinfeld::Feed:#{@url} (#{items.size})>)
    end
  end
end