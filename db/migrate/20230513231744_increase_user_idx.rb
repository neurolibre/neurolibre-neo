class IncreaseUserIdx < ActiveRecord::Migration[7.0]
  def up
    execute "ALTER SEQUENCE users_id_seq RESTART WITH 34;"
  end

  def down
    execute "ALTER SEQUENCE users_id_seq RESTART WITH 1;"
  end
end
