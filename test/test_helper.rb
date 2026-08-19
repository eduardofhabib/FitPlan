ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

class ActiveSupport::TestCase
  # Run tests in parallel with specified workers
  parallelize(workers: :number_of_processors)

  fixtures :all

  # Add more helper methods to be used by all tests here...
  def sign_in_as(user)
    post(sign_in_url, params: { email: user.email, password: "Secret1*3*5*" }); user
  end

  def with_memory_cache
    original = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    yield Rails.cache
  ensure
    Rails.cache = original
  end
end

# PostgreSQL requires superuser privileges to disable FK system triggers, which
# the application test role deliberately does not have. In test only, defer FK
# checks while each fixture batch is loaded; PostgreSQL validates them on the
# transaction commit. Constraints remain immediate during the tests themselves.
module DeferredTestForeignKeys
  def disable_referential_integrity
    execute("SET CONSTRAINTS ALL DEFERRED")
    yield
  end
end

ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.prepend(DeferredTestForeignKeys)
# The adapter check rewrites pg_constraint and also needs superuser privileges.
# The committed fixture transaction above is the database-backed validation.
ActiveRecord.verify_foreign_keys_for_fixtures = false

ActiveRecord::Base.connection_pool.with_connection do |connection|
  constraints = connection.select_rows(<<~SQL)
    SELECT quote_ident(namespace.nspname) || '.' || quote_ident(table_name.relname), quote_ident(constraint_name.conname)
    FROM pg_constraint AS constraint_name
    JOIN pg_class AS table_name ON table_name.oid = constraint_name.conrelid
    JOIN pg_namespace AS namespace ON namespace.oid = table_name.relnamespace
    WHERE constraint_name.contype = 'f'
      AND namespace.nspname = current_schema()
      AND (NOT constraint_name.condeferrable OR constraint_name.condeferred)
  SQL

  constraints.each do |table, constraint|
    connection.execute("ALTER TABLE #{table} ALTER CONSTRAINT #{constraint} DEFERRABLE INITIALLY IMMEDIATE")
  end
end
