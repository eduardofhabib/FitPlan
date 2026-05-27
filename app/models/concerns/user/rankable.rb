module User::Rankable
  extend ActiveSupport::Concern

  def ranking_total_completions
    sheet_completions.count
  end

  def ranking_streak
    sheet_completions.streak
  end

  def ranking_best_day
    weekday_counts = sheet_completions
      .group(Arel.sql("EXTRACT(DOW FROM completed_at)::integer"))
      .count

    weekday_counts.values.max || 0
  end

  def ranking_best_weekday
    sheet_completions.best_weekday
  end
end
