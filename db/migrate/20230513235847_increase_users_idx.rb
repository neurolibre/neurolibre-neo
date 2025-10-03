class IncreaseUsersIdx < ActiveRecord::Migration[7.0]
  def up
    execute "SELECT setval('users_id_seq', COALESCE((SELECT MAX(id) FROM users), 0) + 1, false);"
  end

  def down
    # No-op: Don't reset sequence on rollback
  end
end
