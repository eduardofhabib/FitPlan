require "test_helper"

class Ranking::MetricTest < ActiveSupport::TestCase
  test "find returns default for unknown key" do
    assert_equal Ranking::Metric.default, Ranking::Metric.find("unknown")
  end

  test "catalog includes completion metrics only" do
    expected = %w[total_completions streak best_day]
    assert_equal expected, Ranking::Metric.keys
  end
end
