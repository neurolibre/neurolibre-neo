class AddNeurolibreDoisToPapers < ActiveRecord::Migration[6.1]
  def change
    add_column :papers, :repository_doi, :string
    add_column :papers, :data_doi, :string
    add_column :papers, :book_doi, :string
    add_column :papers, :docker_doi, :string
    add_column :papers, :book_exec_url, :string
  end
end
