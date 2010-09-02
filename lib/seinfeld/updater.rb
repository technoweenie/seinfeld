class Seinfeld
  class Updater
    attr_reader :user

    def self.run(user, today = nil)
      new(user).run(today)
    end

    def initialize(user)
      @user = user
    end

    def run(today = Date.today)
      today   ||= Date.today
      @user.update_location!
      @user.update_timezone!
      Time.zone = @user.time_zone || "UTC"
      if feed = Feed.fetch(@user)
        @user.etag = feed.etag
        @user.update_progress(feed.committed_days, today)
      else
        @user.disabled = true
        @user.save!
      end
      feed
    end
  end
end
