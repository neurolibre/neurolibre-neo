class AddVersionToPapers < ActiveRecord::Migration[7.0]
  def change
    add_column :papers, :version, :string
  end
end
