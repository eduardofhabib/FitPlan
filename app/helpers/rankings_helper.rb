module RankingsHelper
  def rankings_scope_active?(scope)
    @scope == scope
  end

  def rankings_metric_active?(metric)
    @metric.key == metric.key
  end

  def rankings_filter_params(overrides = {})
    { scope: @scope, metric: @metric.key }.merge(overrides)
  end

  def ranking_position_icon(position)
    case position
    when 1 then "bi-trophy-fill text-warning"
    when 2 then "bi-award-fill text-secondary"
    when 3 then "bi-award text-orange"
    else        "bi-hash text-muted"
    end
  end

  def ranking_metric_label(metric)
    t("rankings.metrics.#{metric.key}")
  end

  def ranking_formatted_value(user)
    case @metric.key
    when :streak
      t("rankings.values.days", count: user.ranking_value)
    when :best_day
      ranking_best_day_label(user)
    else
      t("rankings.values.completions", count: user.ranking_value)
    end
  end

  private

    def ranking_best_day_label(user)
      weekday = user.ranking_best_weekday
      return "-" if weekday.nil?

      day_name = t("date.day_names")[weekday]
      t("rankings.values.best_day", day: day_name, count: user.ranking_value)
    end
end
