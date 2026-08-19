require "test_helper"

class RankingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:lazaro_nixon))
  end

  test "should get index" do
    get rankings_url

    assert_response :success
    assert_select "h1", I18n.t("rankings.index.title")
  end

  test "friends ranking includes the current user and mutual friends only" do
    outsider = User.create!(name: "Outsider", email: "outsider@example.com", password: "Secret1*3*5*")

    get rankings_url(metric: "streak", scope: "friends")

    assert_response :success
    assert_select "h2", users(:lazaro).name
    assert_select "h2", users(:lazaro_nixon).name
    assert_select "h2", text: outsider.name, count: 0
  end
end
