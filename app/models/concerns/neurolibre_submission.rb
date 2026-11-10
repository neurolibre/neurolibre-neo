# NeuroLibre-only submission behaviour for Paper, kept out of paper.rb so
# upstream changes to that file merge cleanly.
module NeurolibreSubmission
  extend ActiveSupport::Concern

  NEW_SUBMISSION_DEFAULTS = {
    software_version: "v1.0.0",
    submission_kind: "new",
    git_branch: "main"
  }.freeze

  DOI_FORMAT = %r{\A(https?://(dx\.)?doi\.org/)?10\.\d{4,9}/\S+\z}i

  included do
    # Answer to "Do your data already have a DOI?" ("yes" / "no"). Only the
    # submission form sets it, so papers created elsewhere skip these checks.
    attr_accessor :has_data_doi

    # The form picks a subject; the track is that subject's track, set here
    # rather than taken from the browser.
    before_validation :set_track_from_subject, on: :create
    before_validation :clear_data_doi_unless_declared, on: :create
    validate :data_doi_answered, on: :create
  end

  class_methods do
    # A paper with the submission form's defaults filled in.
    def new_submission(attributes = {})
      new(NEW_SUBMISSION_DEFAULTS.merge(attributes))
    end
  end

  private

  def data_doi_question_asked?
    !has_data_doi.nil?
  end

  def clear_data_doi_unless_declared
    self.data_doi = nil if data_doi_question_asked? && has_data_doi == "no"
  end

  def data_doi_answered
    return unless data_doi_question_asked?

    case has_data_doi
    when "no"
      nil
    when "yes"
      if data_doi.blank?
        errors.add(:base, "Enter your data DOI, or answer No if your data don't have one yet")
      elsif !data_doi.strip.match?(DOI_FORMAT)
        errors.add(:base, "The data DOI should look like 10.5281/zenodo.12345 or https://doi.org/10.5281/zenodo.12345")
      end
    else
      errors.add(:base, "Tell us whether your data already have a DOI")
    end
  end

  def set_track_from_subject
    subject = Subject.find_by(name: suggested_subject) if suggested_subject.present?
    self.track_id = subject.track_id if subject
  end
end
