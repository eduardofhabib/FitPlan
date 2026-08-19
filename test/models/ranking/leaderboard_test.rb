require "test_helper"

class Ranking::LeaderboardTest < ActiveSupport::TestCase
  setup do
    @user = users(:lazaro_nixon)
    @friend = users(:lazaro)
    @outsider = User.create!(name: "Outsider", email: "outsider@example.com", password: "Secret1*3*5*")

    travel_to Time.zone.local(2026, 3, 29, 12)
    SheetCompletion.delete_all
  end

  teardown do
    travel_back
  end

  test "global ranking includes every user and users without completions" do
    complete(@user, at: Time.current)

    entries = leaderboard(scope: "global", metric: "total_completions")

    assert_equal User.order(:id).pluck(:id).sort, entries.map { _1.user.id }.sort
    assert_equal 0, entries.find { _1.user == @outsider }.raw_value
  end

  test "friends ranking includes current user and mutual friends only" do
    entries = leaderboard(scope: "friends", metric: "total_completions")

    assert_equal [@user.id, @friend.id].sort, entries.map { _1.user.id }.sort
    assert_not_includes entries.map { _1.user.id }, @outsider.id
  end

  test "friends ranking excludes a one-way follow" do
    @friend.unfollow!(followed: @user)

    entries = leaderboard(scope: "friends", metric: "total_completions")

    assert_equal [@user.id], entries.map { _1.user.id }
  end

  test "all metrics use the same values as the dashboard relation" do
    2.times { complete(@user, at: Time.current) }
    complete(@user, at: 1.day.ago)
    complete(@user, at: 2.days.ago)

    expected = {
      "total_completions" => @user.sheet_completions.count,
      "completions_today" => @user.sheet_completions.today.count,
      "streak" => @user.sheet_completions.streak
    }

    expected.each do |metric, value|
      entry = leaderboard(scope: "global", metric:).find { _1.user == @user }
      assert_equal value, entry.raw_value, metric
    end

    best_day = leaderboard(scope: "global", metric: "best_day").find { _1.user == @user }
    assert_equal @user.sheet_completions.best_weekday, best_day.metadata[:weekday]
    assert_equal 2, best_day.raw_value
  end

  test "today uses the application timezone boundaries" do
    complete(@user, at: Date.current.beginning_of_day)
    complete(@user, at: Date.current.end_of_day)
    complete(@user, at: Date.current.beginning_of_day - 1.second)

    entry = leaderboard(scope: "global", metric: "completions_today").find { _1.user == @user }

    assert_equal @user.sheet_completions.today.count, entry.raw_value
    assert_equal 2, entry.raw_value
  end

  test "ties share a position and use user id as deterministic order" do
    complete(@user, at: Time.current)
    complete(@friend, at: Time.current)

    entries = leaderboard(scope: "global", metric: "total_completions")
    tied = entries.select { _1.raw_value == 1 }

    assert_equal tied.map { _1.user.id }.sort, tied.map { _1.user.id }
    assert_equal [1], tied.map(&:position).uniq
  end

  test "streak ignores duplicate completions and stops at a gap" do
    2.times { complete(@user, at: Time.current) }
    complete(@user, at: 1.day.ago)
    complete(@user, at: 3.days.ago)

    entry = leaderboard(scope: "global", metric: "streak").find { _1.user == @user }

    assert_equal @user.sheet_completions.streak, entry.raw_value
    assert_equal 2, entry.raw_value
  end

  test "ranking preloads avatars without queries per user" do
    4.times do |index|
      User.create!(name: "User #{index}", email: "user#{index}@example.com", password: "Secret1*3*5*")
    end
    User.columns
    queries = []
    callback = lambda do |_name, _start, _finish, _id, payload|
      queries << payload[:sql] if payload[:sql].start_with?("SELECT") && payload[:name] != "SCHEMA" && !payload[:cached]
    end

    entries = nil
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
      entries = leaderboard(scope: "global", metric: "total_completions")
      entries.each { _1.user.avatar.attached? }
    end

    assert_operator queries.size, :<=, 3, queries.join("\n")
  end

  private

    def leaderboard(scope:, metric:)
      Ranking::Leaderboard.for(scope:, metric:, current_user: @user)
    end

    def complete(user, at:)
      user.sheet_completions.create!(sheet: sheets(:one), completed_at: at)
    end
end
