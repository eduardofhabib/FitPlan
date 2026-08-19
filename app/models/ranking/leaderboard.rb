module Ranking
  class Leaderboard
    SCOPES = %w[global friends].freeze

    Entry = Data.define(:user, :raw_value, :position, :metadata)

    def self.for(scope:, metric:, current_user:)
      users = users_for(scope:, current_user:)
      metric = Metric.find(metric)

      users
        .ranked_by_metric(metric.key)
        .includes(avatar_attachment: :blob)
        .map { entry_for(_1, metric:) }
    end

    def self.users_for(scope:, current_user:)
      return User.all if scope.to_s == "global"

      User.where(id: current_user.friends.select(:id)).or(User.where(id: current_user.id))
    end

    def self.entry_for(user, metric:)
      Entry.new(
        user:,
        raw_value: user.dashboard_metric_value.to_i,
        position: user.ranking_position.to_i,
        metadata: metric.key == :best_day ? { weekday: user.best_weekday&.to_i } : {}
      )
    end

    private_class_method :users_for, :entry_for
  end
end
