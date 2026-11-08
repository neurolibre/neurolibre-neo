class AddVersionToPapers < ActiveRecord::Migration[7.0]
  def change
    add_column :papers, :version, :string, default: 'v1'

    # Backfill existing papers with v1
    reversible do |dir|
      dir.up do
        Paper.where(version: nil).update_all(version: 'v1')
      end
    end
  end
end
