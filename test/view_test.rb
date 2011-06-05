require File.join(File.dirname(__FILE__), "test_helper")
require "rack/test"

ENV['RACK_ENV'] = 'test'

class ViewTest < ActiveSupport::TestCase
  include Rack::Test::Methods

  fixtures do
    @user = Seinfeld::User.create! :login => 'user',
      :longest_streak_start => Date.civil(2007, 12, 30), :longest_streak_end => Date.civil(2007, 12, 31), :longest_streak => 2
    Seinfeld::Progression.create! :user_id => @user.id+1
  end

  def reset_progressions(name)
    user = Seinfeld::User.find_by_login name
    return if user.nil?

    Seinfeld::Progression.delete user.progressions
  end

  def setup
    # run it here in case the DB is screwed up
    reset_progressions @user.login

    now = DateTime.now.to_s
    Seinfeld::Feed.connection = Faraday::Connection.new do |builder|
      builder.adapter :test do |stub|
        stub.get("/user.json") do
          [200, {}, '[{"created_at": "' + now + '", "type": "PushEvent"}]']
        end
      end
    end
  end

  def app
    Seinfeld::App
  end

  test "update user on /:name/update" do
    assert_equal 0, @user.progressions.count
    get "/~#{@user.login}/update"
    assert_equal 1, @user.progressions.count
  end

  test "/:name/update redirects back to /:name when finished" do
    get "/~#{@user.login}/update"
    follow_redirect!

    assert_equal "http://example.org/~#{@user.login}", last_request.url
  end
end
