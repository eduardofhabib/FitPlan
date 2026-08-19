class RankingsController < ApplicationController
  def index
    @scope = params[:scope].presence_in(Ranking::Leaderboard::SCOPES) || "global"
    @metric = Ranking::Metric.find(params[:metric])
    @entries = Ranking::Leaderboard.for(scope: @scope, metric: @metric.key, current_user: Current.user)
  end
end
