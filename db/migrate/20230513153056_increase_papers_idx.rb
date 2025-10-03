class IncreasePapersIdx < ActiveRecord::Migration[7.0]
  def up
    execute "SELECT setval('papers_id_seq', COALESCE((SELECT MAX(id) FROM papers), 0) + 1, false);"
  end

  def down
    # No-op: Don't reset sequence on rollback
  end
end
