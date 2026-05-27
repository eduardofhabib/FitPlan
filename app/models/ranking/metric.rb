module Ranking
  class Metric
    attr_reader :key, :icon

    CATALOG = [
      { key: :total_completions, icon: "bi-bar-chart" },
      { key: :streak,              icon: "bi-trophy" },
      { key: :best_day,            icon: "bi-star" }
    ].freeze

    def self.all
      @all ||= CATALOG.map { new(**_1) }
    end

    def self.keys
      all.map { _1.key.to_s }
    end

    def self.default
      all.first
    end

    def self.find(key)
      all.find { _1.key.to_s == key.to_s } || default
    end

    def initialize(key:, icon:)
      @key  = key
      @icon = icon
    end

    def value_for(user)
      user.public_send(:"ranking_#{key}")
    end

    def metadata_for(user)
      return {} unless key == :best_day

      { weekday: user.ranking_best_weekday }
    end
  end
end
