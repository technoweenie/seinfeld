require File.join(File.dirname(__FILE__), "test_helper")

class FeedTest < ActiveSupport::TestCase
  data = feed_data(:simple)

  setup_once do
   Time.zone = 'Pacific Time (US & Canada)'
   @feed = Seinfeld::Feed.new :technoweenie, data
  end

  test "parses JSON data" do
    assert_kind_of Array, @feed.items
    @feed.items.each { |item| assert_kind_of Hash, item }
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
