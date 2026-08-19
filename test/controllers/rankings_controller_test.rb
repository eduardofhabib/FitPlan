require "test_helper"

class RankingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
    sign_in_as(@user)
  end

  test "requires authentication" do
    reset!

    get rankings_url

    assert_redirected_to welcome_url
  end

  test "renders global ranking and all four metric filters" do
    get rankings_url

    assert_response :success
    assert_select "h1", text: /#{I18n.t('rankings.index.title')}/
    Ranking::Metric.all.each do |metric|
      assert_select "a", text: /#{I18n.t("rankings.metrics.#{metric.key}")}/
    end
  end

  test "friends ranking exposes only current user and mutual friends" do
    outsider = User.create!(name: "Outsider", email: "controller-outsider@example.com", password: "Secret1*3*5*")

    get rankings_url(metric: "streak", scope: "friends")

    assert_response :success
    assert_select "h6", text: /#{users(:lazaro).name}/
    assert_select "h6", text: /#{@user.name}/
    assert_select "h6", text: /#{outsider.name}/, count: 0
  end

  test "invalid filters safely use global and total completions defaults" do
    get rankings_url(metric: "private_data", scope: "user_id")

    assert_response :success
    assert_select "a.btn-primary", text: /#{I18n.t('rankings.metrics.total_completions')}/
    assert_select "a.btn-success", text: /#{I18n.t('rankings.index.scopes.global')}/
  end
end
