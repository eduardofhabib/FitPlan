module Ranking
  class Leaderboard
    SCOPES = %w[global friends].freeze

    def self.for(scope:, metric:, current_user:)
      metric = Metric.find(metric)

      users_for(scope:, current_user:)
        .ranked_by_metric(metric.key)
        .preload(avatar_attachment: :blob)
        .load
    end

    def self.users_for(scope:, current_user:)
      return User.all if scope.to_s == "global"

      User.where(id: current_user.friends.select(:id)).or(User.where(id: current_user.id))
    end

    private_class_method :users_for
  end
end
