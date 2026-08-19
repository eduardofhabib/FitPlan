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

    ranked_users = leaderboard(scope: "global", metric: "total_completions")

    assert_equal User.order(:id).pluck(:id).sort, ranked_users.map(&:id).sort
    assert_equal 0, ranked_users.find { _1 == @outsider }.ranking_value
  end

  test "friends ranking includes current user and mutual friends only" do
    ranked_users = leaderboard(scope: "friends", metric: "total_completions")

    assert_equal [@user.id, @friend.id].sort, ranked_users.map(&:id).sort
    assert_not_includes ranked_users.map(&:id), @outsider.id
  end

  test "friends ranking excludes a one-way follow" do
    @friend.unfollow!(followed: @user)

    ranked_users = leaderboard(scope: "friends", metric: "total_completions")

    assert_equal [@user.id], ranked_users.map(&:id)
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
      ranked_user = leaderboard(scope: "global", metric:).find { _1 == @user }
      assert_equal value, ranked_user.ranking_value, metric
    end

    best_day = leaderboard(scope: "global", metric: "best_day").find { _1 == @user }
    assert_equal @user.sheet_completions.best_weekday, best_day.ranking_best_weekday
    assert_equal 2, best_day.ranking_value
  end

  test "today uses the application timezone boundaries" do
    complete(@user, at: Date.current.beginning_of_day)
    complete(@user, at: Date.current.end_of_day)
    complete(@user, at: Date.current.beginning_of_day - 1.second)

    ranked_user = leaderboard(scope: "global", metric: "completions_today").find { _1 == @user }

    assert_equal @user.sheet_completions.today.count, ranked_user.ranking_value
    assert_equal 2, ranked_user.ranking_value
  end

  test "ties share a position and use user id as deterministic order" do
    complete(@user, at: Time.current)
    complete(@friend, at: Time.current)

    ranked_users = leaderboard(scope: "global", metric: "total_completions")
    tied = ranked_users.select { _1.ranking_value == 1 }

    assert_equal tied.map(&:id).sort, tied.map(&:id)
    assert_equal [1], tied.map(&:ranking_position).uniq
  end

  test "streak ignores duplicate completions and stops at a gap" do
    2.times { complete(@user, at: Time.current) }
    complete(@user, at: 1.day.ago)
    complete(@user, at: 3.days.ago)

    ranked_user = leaderboard(scope: "global", metric: "streak").find { _1 == @user }

    assert_equal @user.sheet_completions.streak, ranked_user.ranking_value
    assert_equal 2, ranked_user.ranking_value
  end

  test "ranking loads only public display attributes" do
    ranked_user = leaderboard(scope: "global", metric: "total_completions").first

    assert ranked_user.has_attribute?(:id)
    assert ranked_user.has_attribute?(:name)
    assert ranked_user.has_attribute?(:handle)
    assert_not ranked_user.has_attribute?(:email)
    assert_not ranked_user.has_attribute?(:password_digest)
  end

  test "ranking preloads avatars without queries per user" do
    4.times do |index|
      User.create!(name: "User #{index}", email: "user#{index}@example.com", password: "Secret1*3*5*")
    end
    User.columns
    Ranking::Metric.keys.each do |metric|
      queries = []
      callback = lambda do |_name, _start, _finish, _id, payload|
        queries << payload[:sql] if payload[:sql].start_with?("SELECT") && payload[:name] != "SCHEMA" && !payload[:cached]
      end

      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
        leaderboard(scope: "global", metric:).each { _1.avatar.attached? }
      end

      assert_operator queries.size, :<=, 3, "#{metric}:\n#{queries.join("\n")}"
    end
  end

  private

    def leaderboard(scope:, metric:)
      Ranking::Leaderboard.for(scope:, metric:, current_user: @user)
    end

    def complete(user, at:)
      user.sheet_completions.create!(sheet: sheets(:one), completed_at: at)
    end
end
