class RankingsController < ApplicationController
  RANKING_SCOPES = %w[global friends].freeze

  def index
    @metric = params[:metric].presence_in(User::RANKING_METRICS) || "total_completions"
    @ranking_scope = params[:scope].presence_in(RANKING_SCOPES) || "global"
    @users = users_for_ranking.ranked_by_metric(@metric).includes(avatar_attachment: :blob)
  end

  private

  def users_for_ranking
    return User.all if @ranking_scope == "global"

    User.where(id: Current.user.friends.select(:id)).or(User.where(id: Current.user.id))
  end
end
