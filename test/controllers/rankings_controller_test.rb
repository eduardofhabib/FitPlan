require "test_helper"

class RankingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:lazaro_nixon)
    sign_in_as(@user)
  end

  test "should get index with friends scope by default" do
    get rankings_url
    assert_response :success
    assert_match I18n.t("rankings.index.scopes.friends"), response.body
  end

  test "should get index with global scope" do
    get rankings_url(scope: "global")
    assert_response :success
    assert_match I18n.t("rankings.index.scopes.global"), response.body
  end

  test "should get index with metric filter" do
    get rankings_url(metric: "streak")
    assert_response :success
    assert_match I18n.t("rankings.metrics.streak"), response.body
  end

  test "ignores invalid scope and metric" do
    get rankings_url(scope: "invalid", metric: "invalid")
    assert_response :success
    assert_match I18n.t("rankings.index.scopes.friends"), response.body
    assert_match I18n.t("rankings.metrics.total_completions"), response.body
  end
end
