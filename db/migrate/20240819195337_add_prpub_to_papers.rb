class AddPrpubToPapers < ActiveRecord::Migration[7.0]
  def change
    add_column :papers, :prpub_doi, :string
    add_column :papers, :prpub_journal, :string
  end
end
