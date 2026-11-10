# NeuroLibre-only submission behaviour for Paper, kept out of paper.rb so
# upstream changes to that file merge cleanly.
module NeurolibreSubmission
  extend ActiveSupport::Concern

  NEW_SUBMISSION_DEFAULTS = {
    software_version: "v1.0.0",
    submission_kind: "new",
    git_branch: "main"
  }.freeze

  included do
    # The form picks a subject; the track is that subject's track, set here
    # rather than taken from the browser.
    before_validation :set_track_from_subject, on: :create
  end

  class_methods do
    # A paper with the submission form's defaults filled in.
    def new_submission(attributes = {})
      new(NEW_SUBMISSION_DEFAULTS.merge(attributes))
    end
  end

  private

  def set_track_from_subject
    subject = Subject.find_by(name: suggested_subject) if suggested_subject.present?
    self.track_id = subject.track_id if subject
  end
end
