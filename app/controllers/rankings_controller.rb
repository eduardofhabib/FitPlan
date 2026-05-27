class RankingsController < ApplicationController
  SCOPES = %w[friends global].freeze

  def index
    @scope  = SCOPES.include?(params[:scope]) ? params[:scope] : "friends"
    @metric = Ranking::Metric.find(params[:metric])
    @entries = Ranking::Leaderboard.for(scope: @scope, metric: @metric.key, current_user: Current.user)
  end
end
