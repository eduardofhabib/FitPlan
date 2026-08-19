class User < ApplicationRecord
  RANKING_METRICS = %w[total_completions best_day completions_today streak].freeze

  include Normalizable
  include User::Followable
  include User::Shareable

  has_secure_password
  has_one_attached :avatar

  generates_token_for :email_verification, expires_in: 2.days do
    email
  end
  generates_token_for :password_reset, expires_in: 20.minutes do
    password_salt.last(10)
  end

  has_one  :healthy_metric,     dependent: :destroy
  has_many :sessions,           dependent: :destroy
  has_many :sheets,             dependent: :destroy
  has_many :sheet_completions

  validate :avatar_size

  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, allow_nil: true, length: { minimum: 6 }
  validates :handle, presence: true, uniqueness: true, length: { minimum: 3 },
                     format: { with: /\A[a-z0-9]+(?:-[a-z0-9]+)*\z/ }, on: :update

  normalizes :email, :handle, with: -> { _1.strip.downcase }

  before_validation if: :email_changed?, on: :update do
    self.verified = false
  end

  before_create :generate_handle_unique

  after_update if: :password_digest_previously_changed? do
    sessions.where.not(id: Current.session).delete_all
  end

  def self.search_users(query)
    return none unless query.present?

    where("name ILIKE :search OR handle ILIKE :search", search: "%#{sanitize_search(query)}%")
  end

  scope :ranked_by_completions, -> { ranked_by_metric(:total_completions) }

  scope :ranked_by_metric, ->(metric) {
    metric = metric.to_s
    raise ArgumentError, "Unknown ranking metric: #{metric}" unless RANKING_METRICS.include?(metric)

    case metric
    when "total_completions"
      ranked_by_completion_count("LEFT JOIN sheet_completions AS ranking_completions ON ranking_completions.user_id = users.id", legacy_alias: true)
    when "completions_today"
      ranked_by_completion_count(<<~SQL.squish)
        LEFT JOIN sheet_completions AS ranking_completions
          ON ranking_completions.user_id = users.id
         AND ranking_completions.completed_at BETWEEN #{SheetCompletion.connection.quote(Date.current.all_day.begin)}
                                                 AND #{SheetCompletion.connection.quote(Date.current.all_day.end)}
      SQL
    when "best_day"
      ranked_by_derived_metric(
        best_day_ranking_join,
        "best_day_metrics.metric_value",
        "best_day_metrics.weekday",
        order: Arel.sql("COALESCE(best_day_metrics.metric_value, 0) DESC, users.id ASC")
      )
    when "streak"
      ranked_by_derived_metric(
        streak_ranking_join,
        "streak_metrics.metric_value",
        order: Arel.sql("COALESCE(streak_metrics.metric_value, 0) DESC, users.id ASC")
      )
    end
  }

  def self.ranked_by_completion_count(join, legacy_alias: false)
    metric_value = "COUNT(ranking_completions.id)"
    legacy_select = ", #{metric_value} AS completions_count" if legacy_alias

    joins(join)
      .select(<<~SQL.squish)
        users.*, #{metric_value} AS dashboard_metric_value#{legacy_select},
        DENSE_RANK() OVER (ORDER BY #{metric_value} DESC) AS ranking_position
      SQL
      .group(:id)
      .order(Arel.sql("#{metric_value} DESC, users.id ASC"))
  end

  def self.ranked_by_derived_metric(join, metric_value, weekday = nil, order:)
    metric_value = "COALESCE(#{metric_value}, 0)"
    weekday_select = ", #{weekday} AS best_weekday" if weekday

    joins(join)
      .select(<<~SQL.squish)
        users.*, #{metric_value} AS dashboard_metric_value#{weekday_select},
        DENSE_RANK() OVER (ORDER BY #{metric_value} DESC) AS ranking_position
      SQL
      .order(order)
  end

  def self.best_day_ranking_join
    <<~SQL.squish
      LEFT JOIN (
        SELECT user_id, weekday, completions_count AS metric_value
        FROM (
          SELECT user_id, weekday, completions_count,
                 ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY completions_count DESC, weekday ASC) AS position
          FROM (
            SELECT user_id, EXTRACT(DOW FROM completed_at)::integer AS weekday, COUNT(*) AS completions_count
            FROM sheet_completions
            GROUP BY user_id, EXTRACT(DOW FROM completed_at)::integer
          ) AS weekday_counts
        ) AS ranked_weekdays
        WHERE position = 1
      ) AS best_day_metrics ON best_day_metrics.user_id = users.id
    SQL
  end

  def self.streak_ranking_join
    current_date = SheetCompletion.connection.quote(Date.current)

    <<~SQL.squish
      LEFT JOIN (
        SELECT user_id, COUNT(*) AS metric_value
        FROM (
          SELECT user_id, completed_on,
                 ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY completed_on DESC) AS day_number
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

  def to_param
    handle
  end

  def online?
    Rails.cache.exist?("user_online:#{id}")
  end

  private

  def avatar_size
    errors.add(:avatar, :error_avatar_size) if avatar.attached? && avatar.blob.byte_size > 4.megabytes
  end

  def generate_handle_unique
    loop do
      self.handle = "#{name.parameterize}-#{SecureRandom.hex(4)}"
      break unless User.exists?(handle: handle)
    end
  end
end
