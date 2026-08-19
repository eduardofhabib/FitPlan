module User::Rankable
  extend ActiveSupport::Concern

  def ranking_value
    self[:dashboard_metric_value].to_i
  end

  def ranking_position
    self[:ranking_position].to_i
  end

  def ranking_best_weekday
    self[:best_weekday]&.to_i
  end

  class_methods do
    def ranked_by_metric(metric)
      case metric.to_s
      when "total_completions"
        ranked_by_completion_count(
          "LEFT JOIN sheet_completions AS ranking_completions ON ranking_completions.user_id = users.id"
        )
      when "completions_today"
        ranked_by_completion_count(<<~SQL.squish)
          LEFT JOIN sheet_completions AS ranking_completions
            ON ranking_completions.user_id = users.id
           AND ranking_completions.completed_at BETWEEN #{connection.quote(Date.current.all_day.begin)}
                                                   AND #{connection.quote(Date.current.all_day.end)}
        SQL
      when "best_day"
        ranked_by_derived_metric(
          best_day_ranking_join,
          "best_day_metrics.metric_value",
          "best_day_metrics.weekday"
        )
      when "streak"
        ranked_by_derived_metric(streak_ranking_join, "streak_metrics.metric_value")
      else
        raise ArgumentError, "Unknown ranking metric: #{metric}"
      end
    end

    private

      def ranked_by_completion_count(join)
        metric_value = "COUNT(ranking_completions.id)"

        joins(join)
          .select(ranking_select(metric_value))
          .group(:id)
          .order(Arel.sql("dashboard_metric_value DESC, users.id ASC"))
      end

      def ranked_by_derived_metric(join, value, weekday = nil)
        metric_value = "COALESCE(#{value}, 0)"
        weekday_select = ", #{weekday} AS best_weekday" if weekday

        joins(join)
          .select(ranking_select(metric_value, weekday_select))
          .order(Arel.sql("dashboard_metric_value DESC, users.id ASC"))
      end

      def ranking_select(metric_value, extra_select = nil)
        <<~SQL.squish
          users.id, users.name, users.handle,
          #{metric_value} AS dashboard_metric_value#{extra_select},
          DENSE_RANK() OVER (ORDER BY #{metric_value} DESC) AS ranking_position
        SQL
      end

      def best_day_ranking_join
        <<~SQL.squish
          LEFT JOIN (
            SELECT DISTINCT ON (user_id)
                   user_id,
                   EXTRACT(DOW FROM completed_at)::integer AS weekday,
                   COUNT(*) AS metric_value
            FROM sheet_completions
            GROUP BY user_id, EXTRACT(DOW FROM completed_at)::integer
            ORDER BY user_id, COUNT(*) DESC, EXTRACT(DOW FROM completed_at)::integer ASC
          ) AS best_day_metrics ON best_day_metrics.user_id = users.id
        SQL
      end

      def streak_ranking_join
        current_date = connection.quote(Date.current)

        <<~SQL.squish
          LEFT JOIN (
            SELECT user_id, COUNT(*) AS metric_value
            FROM (
              SELECT user_id, completed_on,
                     ROW_NUMBER() OVER (
                       PARTITION BY user_id
                       ORDER BY completed_on DESC
                     ) AS day_number
              FROM (
                SELECT DISTINCT user_id, DATE(completed_at) AS completed_on
                FROM sheet_completions
              ) AS completion_days
            ) AS numbered_days
            WHERE completed_on = #{current_date}::date - (day_number - 1)::integer
            GROUP BY user_id
          ) AS streak_metrics ON streak_metrics.user_id = users.id
        SQL
      end
  end
end
