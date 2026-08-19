require "test_helper"

class UserTest < ActiveSupport::TestCase
  # handle --------------------------------------------------------------------

  test "generates handle on create" do
    user = User.create!(name: "Jane Doe", email: "jane@example.com", password: "Secret1*3*5*")
    assert_match(/\Ajane-doe-[0-9a-f]{8}\z/, user.handle)
  end

  test "generates unique handles for users with the same name" do
    user1 = User.create!(name: "Same Name", email: "same1@example.com", password: "Secret1*3*5*")
    user2 = User.create!(name: "Same Name", email: "same2@example.com", password: "Secret1*3*5*")
    assert_not_equal user1.handle, user2.handle
  end

  test "handle must be unique on update" do
    user = users(:lazaro_nixon)
    user.handle = users(:lazaro).handle
    assert_not user.valid?
  end

  test "to_param returns handle" do
    assert_equal users(:lazaro_nixon).handle, users(:lazaro_nixon).to_param
  end

  # search --------------------------------------------------------------------

  test "search_users returns users matching by name" do
    results = User.search_users("lazaro_nixon")
    assert_includes results, users(:lazaro_nixon)
    assert_includes results, users(:lazaro)
  end

  test "search_users returns user matching by handle" do
    results = User.search_users("1234")
    assert_includes results, users(:lazaro_nixon)
    assert_not_includes results, users(:lazaro)
  end

  test "search_users is case insensitive" do
    results = User.search_users("LAZARO_NIXON")
    assert_includes results, users(:lazaro_nixon)
  end

  test "search_users returns none with blank query" do
    assert_empty User.search_users("")
    assert_empty User.search_users(nil)
  end

  test "search_users returns none when no match" do
    assert_empty User.search_users("nonexistent_user_xyz")
  end

  # ranking -------------------------------------------------------------------

  test "ranked_by_completions orders users by completed sheets and preserves ties" do
    first = users(:lazaro_nixon)
    second = users(:lazaro)
    third = User.create!(name: "Third User", email: "third@example.com", password: "Secret1*3*5*")

    first.sheet_completions.destroy_all
    first.sheet_completions.create!(sheet: sheets(:one))
    first.sheet_completions.create!(sheet: sheets(:two))
    second.sheet_completions.create!(sheet: sheets(:one))
    second.sheet_completions.create!(sheet: sheets(:two))

    ranked_users = User.ranked_by_completions.to_a

    assert_equal [first, second].sort_by(&:id) + [third], ranked_users
    assert_equal [2, 2, 0], ranked_users.map { _1.completions_count.to_i }
    assert_equal [1, 1, 2], ranked_users.map { _1.ranking_position.to_i }
  end

  test "ranked_by_metric uses the same sheet completion metrics as the dashboard" do
    first = users(:lazaro_nixon)
    second = users(:lazaro)

    travel_to Time.zone.local(2026, 3, 29, 12, 0, 0) do
      SheetCompletion.delete_all

      2.times { first.sheet_completions.create!(sheet: sheets(:one), completed_at: Time.current) }
      first.sheet_completions.create!(sheet: sheets(:one), completed_at: 1.day.ago)
      first.sheet_completions.create!(sheet: sheets(:one), completed_at: 2.days.ago)

      second.sheet_completions.create!(sheet: sheets(:one), completed_at: Time.current)
      second.sheet_completions.create!(sheet: sheets(:one), completed_at: 1.day.ago)
      second.sheet_completions.create!(sheet: sheets(:one), completed_at: 2.days.ago)

      assert_equal [4, 3], User.where(id: [first, second]).ranked_by_metric(:total_completions).map { _1.dashboard_metric_value.to_i }
      assert_equal [2, 1], User.where(id: [first, second]).ranked_by_metric(:completions_today).map { _1.dashboard_metric_value.to_i }
      assert_equal [3, 3], User.where(id: [first, second]).ranked_by_metric(:streak).map { _1.dashboard_metric_value.to_i }

      first_ranking = User.where(id: first.id).ranked_by_metric(:best_day).first
      assert_equal first.sheet_completions.count, User.where(id: first.id).ranked_by_metric(:total_completions).first.dashboard_metric_value.to_i
      assert_equal first.sheet_completions.today.count, User.where(id: first.id).ranked_by_metric(:completions_today).first.dashboard_metric_value.to_i
      assert_equal first.sheet_completions.streak, User.where(id: first.id).ranked_by_metric(:streak).first.dashboard_metric_value.to_i
      assert_equal first.sheet_completions.best_weekday, first_ranking.best_weekday.to_i

      best_day_ranking = User.where(id: [first, second]).ranked_by_metric(:best_day).to_a
      assert_equal [2, 1], best_day_ranking.map { _1.dashboard_metric_value.to_i }
      assert_equal [0, 0], best_day_ranking.map { _1.best_weekday.to_i }
      assert_equal [1, 2], best_day_ranking.map { _1.ranking_position.to_i }
    end
  end
end
