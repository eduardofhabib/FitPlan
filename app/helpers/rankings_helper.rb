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

  def ranking_formatted_value(entry)
    case @metric.key
    when :streak
      "#{entry.raw_value.to_i} #{t('dashboard.index.cards.days')}"
    when :best_day
      ranking_best_day_label(entry)
    else
      entry.raw_value.to_i.to_s
    end
  end

  private

    def ranking_best_day_label(entry)
      weekday = entry.metadata[:weekday]
      return "-" if weekday.nil?

      day_name = t("date.day_names")[weekday]
      count = entry.raw_value.to_i
      count.positive? ? "#{day_name} (#{count})" : day_name
    end
end
