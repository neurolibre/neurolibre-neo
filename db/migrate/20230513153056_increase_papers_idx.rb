class IncreasePapersIdx < ActiveRecord::Migration[7.0]
  def up
    execute "ALTER SEQUENCE papers_id_seq RESTART WITH 5;"
  end

  def down
    execute "ALTER SEQUENCE papers_id_seq RESTART WITH 1;"
  end
end
