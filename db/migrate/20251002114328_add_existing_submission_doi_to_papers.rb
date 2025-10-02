class AddExistingSubmissionDoiToPapers < ActiveRecord::Migration[7.0]
  def change
    add_column :papers, :existing_submission_doi, :string
  end
end