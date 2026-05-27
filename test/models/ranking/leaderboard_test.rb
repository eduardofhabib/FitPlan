require "test_helper"

class Ranking::LeaderboardTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @friend = users(:lazaro)
    travel_to Time.zone.local(2026, 3, 29, 12, 0, 0)
  end

  teardown do
    travel_back
  end

  test "for friends ranks by selected metric" do
    @user.sheet_completions.destroy_all
    @user.sheet_completions.create!(sheet: sheets(:one), completed_at: Time.current)

    @friend.sheet_completions.destroy_all
    3.times { |i| @friend.sheet_completions.create!(sheet: sheets(:two), completed_at: i.days.ago) }

    entries = Ranking::Leaderboard.for(scope: "friends", metric: "streak", current_user: @user)

    assert_includes entries.map { |e| e.user.id }, @user.id
    assert_includes entries.map { |e| e.user.id }, @friend.id
    assert_equal entries.map(&:raw_value), entries.map(&:raw_value).sort.reverse
    assert_equal (1..entries.size).to_a, entries.map(&:position)
  end

  test "for global ranks all users" do
    entries = Ranking::Leaderboard.for(scope: "global", metric: "total_completions", current_user: @user)

    assert_equal User.count, entries.size
    assert entries.first.raw_value >= entries.last.raw_value
  end
end
