class RenameExistingSubmissionDoiToPublishedParentDoi < ActiveRecord::Migration[7.0]
  def change
    rename_column :papers, :existing_submission_doi, :published_parent_doi
  end
end
