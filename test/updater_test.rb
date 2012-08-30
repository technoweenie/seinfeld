require File.join(File.dirname(__FILE__), "test_helper")

class UpdaterTest < ActiveSupport::TestCase
  data = feed_data(:simple)

  fixtures do
    @dead = Seinfeld::User.create! :login => 'fred'
    @user = Seinfeld::User.create! :login => 'bob',
      :time_zone => 'Pacific Time (US & Canada)'
    Seinfeld::Feed.connection = \
      Faraday::Connection.new do |builder|
        builder.adapter :test do |stub|
          stub.get('/users/bob/events?page=1') do 
            [200, {"etag" => "abc"}, data]
          end
          stub.get('/users/fred/events?page=1') do
            [404, {}, '[]']
          end
          stub.get('/users/bob') do
            [200, {}, '{}']
          end
          stub.get('/users/fred') do
            [200, {}, '{}']
          end
        end
      end
    @feed = Seinfeld::Updater.run(@user)
  end

  test "saves latest ETag from feed" do
    assert_equal 'abc', @feed.etag
    assert_equal @feed.etag, @user.reload.etag
  end

  test "parses atom entries" do
    assert_equal 9, @feed.items.size
  end

  test "parses entry published timestamp" do
    assert_equal Time.zone.local(2009, 12, 19, 14, 42, 13), Time.zone.parse(@feed.items[0]['created_at'])
  end

  test "scans for committed days" do
    assert_equal [
      Date.civil(2009, 12, 19),
      Date.civil(2009, 12, 17),
      Date.civil(2009, 12, 16),
      Date.civil(2009, 12, 15),
      Date.civil(2009, 12, 12)], @feed.committed_days
  end
end
