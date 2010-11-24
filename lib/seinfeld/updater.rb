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
      old_location = @user.location
      @user.update_location!
      @user.update_timezone! if old_location != @user.location
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
