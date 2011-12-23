class Seinfeld
  class Updater
    attr_reader :user

    def self.run(user, today = nil, page = nil)
      new(user).run(today, page)
    end

    def initialize(user)
      @user = user
    end

    def run(today = Date.today, page = nil)
      today   ||= Date.today
      old_location = @user.location
      @user.update_location!
      @user.update_timezone! if old_location != @user.location
      Time.zone = @user.time_zone || "UTC"
      feed = Feed.fetch(@user, page)
      if feed.disabled?
        @user.disabled = true
        @user.save!
        nil
      else
        @user.etag = feed.etag
        @user.update_progress(feed.committed_days, today)
        feed
      end
    end
  end
end
