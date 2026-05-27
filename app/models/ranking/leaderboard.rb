module Ranking
  class Leaderboard
    Entry = Data.define(:user, :raw_value, :position, :metadata)

    def self.for(scope:, metric:, current_user:)
      users = users_for(scope:, current_user:)
      build(users, metric: Metric.find(metric))
    end

    def self.users_for(scope:, current_user:)
      base = User.includes(avatar_attachment: :blob).order(:name)

      case scope.to_s
      when "global" then base
      else               base.friends_of(current_user)
      end
    end

    def self.build(users, metric:)
      entries = users.map { entry_for(_1, metric) }
      entries.sort_by! { -_1.raw_value.to_f }
      entries.each_with_index.map { |entry, index| entry.with(position: index + 1) }
    end

    def self.entry_for(user, metric)
      Entry.new(
        user:,
        raw_value: metric.value_for(user),
        position: 0,
        metadata: metric.metadata_for(user)
      )
    end

    private_class_method :users_for, :build, :entry_for
  end
end
