require 'open3'

class Paper < ApplicationRecord
  searchkick index_name: "neurolibre-production"

  include SettingsHelper
  serialize :activities, Hash
  serialize :metadata, Hash

  belongs_to :submitting_author,
             class_name: 'User',
             validate: true,
             foreign_key: "user_id"

  belongs_to :track, optional: true
  belongs_to :editor, optional: true
  belongs_to :eic,
             class_name: 'Editor',
             optional: true,
             foreign_key: "eic_id"

  has_many :invitations
  has_many :notes
  has_many :votes
  has_many :in_scope_votes,
           -> { in_scope },
           class_name: 'Vote'

  has_many :out_of_scope_votes,
           -> { out_of_scope },
           class_name: 'Vote'

  include AASM

  aasm column: :state do
    state :submitted, initial: true
    state :review_pending
    state :under_review
    state :review_completed
    state :superceded
    state :accepted
    state :rejected
    state :retracted
    state :withdrawn

    event :reject do
      transitions to: :rejected, after: :expire_invitations
    end

    event :start_meta_review do
      transitions from: :submitted, to: :review_pending, if: :create_meta_review_issue
    end

    event :start_review do
      transitions from: :review_pending, to: :under_review, if: :create_review_issue
    end

    event :accept do
      transitions to: :accepted
    end

    event :withdraw do
      transitions to: :withdrawn
    end
  end

  VISIBLE_STATES = [
    "accepted",
    "superceded",
    "retracted"
  ].freeze

  PUBLIC_IN_PROGRESS_STATES = [
    "under_review",
    "review_pending"
  ].freeze

  IN_PROGRESS_STATES = [
    "submitted",
    "under_review",
    "review_pending"
  ].freeze

  INVISIBLE_STATES = [
    "submitted",
    "rejected",
    "withdrawn"
  ].freeze

  SUBMISSION_KINDS = [
    "new",
    "resubmission",
    "new version"
  ]

  # Languages we don't show in the UI
  IGNORED_LANGUAGES = [
    'Shell',
    'TeX',
    'Makefile',
    'HTML',
    'CSS',
    'CMake'
  ].freeze

  default_scope  { order(created_at: :desc) }
  scope :recent, lambda { where('created_at > ?', 1.week.ago) }
  scope :submitted, lambda { where('state = ?', 'submitted') }

  scope :since, -> (date) { where('accepted_at >= ?', date) }
  scope :in_progress, -> { where(state: IN_PROGRESS_STATES) }
  scope :public_in_progress, -> { where(state: PUBLIC_IN_PROGRESS_STATES) }
  scope :visible, -> { where(state: VISIBLE_STATES) }
  scope :invisible, -> { where(state: INVISIBLE_STATES) }
  scope :public_everything, lambda { where('state NOT IN (?)', ['submitted', 'rejected', 'withdrawn']) }
  scope :everything, lambda { where('state NOT IN (?)', ['rejected', 'withdrawn']) }
  scope :search_import, -> { where(state: VISIBLE_STATES) }
  scope :not_archived, -> { where('archived = ?', false) }
  scope :by_track, -> (track_id) { where('track_id = ?', track_id) }

  before_create :set_sha, :set_last_activity
  after_create :notify_editors, :notify_author

  validates_presence_of :title, message: "The paper must have a title"
  validates_presence_of :repository_url, message: "Repository address can't be blank"
  validates_presence_of :software_version, message: "Version can't be blank"
  validates_presence_of :body, message: "Description can't be blank"
  validates_presence_of :track_id, on: :create, message: "You must select a valid subject for the paper"
  validates :kind, inclusion: { in: Rails.application.settings["paper_types"] }, allow_nil: true
  validates :submission_kind, inclusion: { in: SUBMISSION_KINDS, message: "You must select a submission type" }, allow_nil: false
  validate :check_repository_address, on: :create

  def notify_editors
    Notifications.submission_email(self).deliver_now
  end

  def notify_author
    Notifications.author_submission_email(self).deliver_now
  end

  # Only index papers that are visible
  def should_index?
    !invisible?
  end

  def search_data
    {
      accepted_at: accepted_at,
      authors: scholar_authors,
      reviewers: metadata_reviewers,
      editor: metadata_editor,
      issue: issue,
      languages: language_tags,
      page: page,
      tags: author_tags,
      title: scholar_title,
      volume: volume,
      year: year
    }
  end

  def self.featured
    # TODO: Make this a thing
    Paper.first
  end

  def self.popular
    recent
  end

  def published?
    accepted? || retracted?
  end

  def invite_editor(editor_handle)
    return false unless editor = Editor.find_by_login(editor_handle)
    Notifications.editor_invite_email(self, editor).deliver_now
    invitations.create(editor: editor)
  end

  def expire_invitations
    Invitation.expire_all_for_paper(self)
  end

  def scholar_title
    return nil unless published?
    metadata['paper']['title']
  end

  def scholar_authors
    return nil unless published?
    metadata['paper']['authors'].collect {|a| "#{a['given_name']} #{a['middle_name']} #{a['last_name']}".squish}.join(', ')
  end

  def bibtex_authors
    return nil unless published?
    metadata['paper']['authors'].collect {|a| "#{a['given_name']} #{a['middle_name']} #{a['last_name']}".squish}.join(' and ')
  end

  def bibtex_key
    return nil unless published?
    "#{metadata['paper']['authors'].first['last_name']}#{year}"
  end

  def language_tags
    return [] unless published?
    metadata['paper']['languages'] - IGNORED_LANGUAGES
  end

  def author_tags
    return [] unless published?
    if metadata['paper']['tags']
      return metadata['paper']['tags'] - language_tags
    else
      return []
    end
  end

  def metadata_reviewers
    return [] unless published?
    metadata['paper']['reviewers']
  end

  def metadata_editor
    return nil unless published?
    metadata['paper']['editor']
  end

  def metadata_authors
    return nil unless published?
    metadata['paper']['authors']
  end

  def issue
    return nil unless published?
    metadata['paper']['issue']
  end

  def volume
    return nil unless published?
    metadata['paper']['volume']
  end

  def year
    return nil unless published?
    metadata['paper']['year']
  end

  def page
    return nil unless published?
    metadata['paper']['page']
  end

  def to_param
    sha
  end

  def invisible?
    INVISIBLE_STATES.include?(state)
  end

  def pretty_repository_name
    if repository_url.include?('github.com')
      name, owner = repository_url.scan(/(?<=github.com\/).*/i).first.split('/')
      return "#{name} / #{owner}"
    else
      return repository_url
    end
  end

  # @NeuroLibre -- START
  # JOSS uses archive_doi here, which corresponds to repository_doi 
  # in NeuroLibre glosary. Hence changed to repository_doi.
  # In THEOJ, the word archive suffices (only repository is archived)
  # NeuroLibre archives 4 reproducibility assets.
  def pretty_doi
    return "DOI pending" unless repository_doi

    matches = repository_doi.scan(/\b(10[.][0-9]{4,}(?:[.][0-9]+)*\/(?:(?!["&\'<>])\S)+)\b/).flatten

    if matches.any?
      return matches.first
    else
      return repository_doi
    end
  end

  # Make sure that DOIs have a full http URL
  # e.g. turn 10.6084/m9.figshare.828487 into https://doi.org/10.6084/m9.figshare.828487
  # Returns a DOI as a full https://doi.org/ URL, or "DOI pending" if missing.
  # Accepts a string (the DOI field), so it can be reused for any DOI attribute.
  def self.doi_with_url_for(doi_value)
    return "DOI pending" if doi_value.blank?

    bare_doi = doi_value[/\b(10[.][0-9]{4,}(?:[.][0-9]+)*\/(?:(?!["&\'<>])\S)+)\b/]

    if doi_value.include?("https://doi.org/")
      doi_value
    elsif bare_doi
      "https://doi.org/#{bare_doi}"
    else
      doi_value
    end
  end

  def doi_with_url
    self.class.doi_with_url_for(repository_doi)
  end

  def published_parent_doi_with_url
    self.class.doi_with_url_for(published_parent_doi)
  end

  def clean_repository_doi
    doi_with_url.gsub(/\"/, "")
  end

  def clean_published_parent_doi
    published_parent_doi_with_url.gsub(/\"/, "")
  end

  # A 5-figure integer used to produce the JOSS DOI
  def joss_id
    id = "%05d" % review_issue_id
    "#{setting(:abbreviation).downcase}.#{id}"
  end

  # This URL returns the 'DOI optimized' representation of a URL for a paper
  # e.g. https://joss.theoj.org/papers/10.21105/joss.01632 rather than something
  # with the SHA e.g. https://joss.theoj.org/papers/5e290cb57b61f83de4460fd0eca22726
  # This URL format only works for accepted papers so falls back to the SHA
  # version if no DOI is set.
  def seo_url
    if accepted?
      # @NeuroLibre
      "#{Rails.application.settings["url"]}/papers/#{Rails.application.settings["doi_prefix"]}/#{joss_id}"
    else
      "#{Rails.application.settings["url"]}/papers/#{to_param}"
    end
  end

  # Return the seo_url plus '.pdf'. This is for Google Scholar so that we can
  # point to PDFs on the same domain on the JOSS site (although they are then
  # 301 redirected to a pdf_url later).
  def seo_pdf_url
    "#{seo_url}.pdf"
  end

  # Where to find the PDF for this paper
  def pdf_url
    doi_to_file = doi.gsub('/', '.')

    "#{Rails.application.settings["papers_html_url"]}/#{Rails.application.settings[:doi_prefix]}/#{joss_id}.pdf"
  end

  # 'reviewers' should be a string (and may be comma-separated)
  def review_body(editor, reviewers, branch=nil)
    reviewers = reviewers.split(',').each {|r| r.prepend('@')}
    ApplicationController.render(
      template: 'shared/review_body',
      formats: :text,
      locals: { paper: self, editor: "@#{editor}", reviewers: reviewers, branch: branch }
    )
  end

  # Create a review issue (we know the reviewer and editor at this point)
  # Return false if the review_issue_id is already set
  # Return false if the editor login doesn't match one of the known editors
  def create_review_issue(editor_handle, reviewers, branch=nil)
    return false if review_issue_id
    return false unless editor = Editor.find_by_login(editor_handle)

    if labels.any?
      new_labels = labels.keys + ["review"] - ["pre-review"]
    else
      new_labels = ["review"]
    end


    issue = GITHUB.create_issue(Rails.application.settings["reviews"],
                                "[REVIEW]: #{self.title}",
                                review_body(editor_handle, reviewers, branch),
                                { assignees: [editor_handle],
                                  labels: new_labels.join(",") })

    set_review_issue(issue.number)
    set_editor(editor)
    set_reviewers(reviewers)
  end

  # Update the paper with the reviewer GitHub handles
  def set_reviewers(reviewers)
    reviewers = reviewers.split(',').each(&:strip!).each {|r| r.prepend('@') unless r.start_with?('@') }
    self.update_attribute(:reviewers, reviewers)
  end

  # Updated the paper with the editor_id
  def set_editor(editor)
    self.update_attribute(:editor_id, editor.id)
    Invitation.resolve_pending(self, editor)
  end

  # Update the Paper review_issue_id field
  def set_review_issue(issue_number)
    self.update_attribute(:review_issue_id, issue_number)
  end

  def meta_review_body(editor, eic_name)
    if editor.strip.empty?
      locals = { paper: self, suggested_editor: "Pending", eic_name: eic_name }
    else
      locals = { paper: self, suggested_editor: "#{editor}", eic_name: eic_name }
    end
    ApplicationController.render(
      template: 'shared/meta_view_body',
      formats: :text,
      locals: locals
    )
  end

  # Create a review meta-issue for assigning reviewers
  def create_meta_review_issue(editor_handle, eic, new_track_id=nil)
    return false if meta_review_issue_id

    set_track_id(new_track_id) if new_track_id.present?
    new_labels = ["pre-review", self.track.label]

    issue = GITHUB.create_issue(Rails.application.settings["reviews"],
                                "[PRE REVIEW]: #{self.title}",
                                meta_review_body(editor_handle, eic.full_name),
                                { labels: new_labels.join(",") })

    set_meta_review_issue(issue.number)
    set_meta_eic(eic)
  end

  # Update the Paper meta_review_issue_id field
  def set_meta_review_issue(issue_number)
    self.update_attribute(:meta_review_issue_id, issue_number)
  end

  def set_meta_eic(eic)
    self.update_attribute(:eic_id, eic.id)
  end

  def set_track_id(new_track_id)
    self.update_attribute(:track_id, new_track_id) if new_track_id != self.track_id
  end

  def move_to_track(new_track)
    return if new_track.nil?
    old_track = self.track
    current_label = self.track.present? ? self.track.label : ""
    if current_label != new_track.label
      set_track_id(new_track.id)

      Notifications.notify_new_aeic(self, old_track, new_track).deliver_now

      if self.meta_review_issue_id
        GITHUB.remove_label(Rails.application.settings["reviews"], self.meta_review_issue_id, current_label) if current_label.present?
        GITHUB.add_labels_to_an_issue(Rails.application.settings["reviews"], self.meta_review_issue_id, [new_track.label])
      end

      if self.review_issue_id
        GITHUB.remove_label(Rails.application.settings["reviews"], self.review_issue_id, current_label) if current_label.present?
        GITHUB.add_labels_to_an_issue(Rails.application.settings["reviews"], self.review_issue_id, [new_track.label])
      end
    end
  end

  def meta_review_url
    "https://github.com/#{Rails.application.settings["reviews"]}/issues/#{self.meta_review_issue_id}"
  end

  def review_url
    "https://github.com/#{Rails.application.settings["reviews"]}/issues/#{self.review_issue_id}"
  end

  def update_review_issue(comment)
    GITHUB.add_comment(Rails.application.settings["reviews"], self.review_issue_id, comment)
  end

  def pretty_state
    state.humanize.downcase
  end

  # Returns DOI with URL e.g. "https://doi.org/10.21105/joss.00001"
  def cross_ref_doi_url
    "https://doi.org/#{doi}"
  end

  def status_badge
    prefix = setting(:abbreviation)

    case self.state.to_s
    when "submitted"
      "<svg xmlns='http://www.w3.org/2000/svg' width='108' height='20'><linearGradient id='b' x2='0' y2='100%'><stop offset='0' stop-color='#bbb' stop-opacity='.1'/><stop offset='1' stop-opacity='.1'/></linearGradient><mask id='a'><rect width='108' height='20' rx='3' fill='#fff'/></mask><g mask='url(#a)'><path fill='#555' d='M0 0h40v20H0z'/><path fill='#007ec6' d='M40 0h68v20H40z'/><path fill='url(#b)' d='M0 0h108v20H0z'/></g><g fill='#fff' text-anchor='middle' font-family='DejaVu Sans,Verdana,Geneva,sans-serif' font-size='11'><text x='20' y='15' fill='#010101' fill-opacity='.3'>#{prefix}</text><text x='20' y='14'>#{prefix}</text><text x='73' y='15' fill='#010101' fill-opacity='.3'>Submitted</text><text x='73' y='14'>Submitted</text></g></svg>"
    when "review_pending"
      "<svg xmlns='http://www.w3.org/2000/svg' width='108' height='20'><linearGradient id='b' x2='0' y2='100%'><stop offset='0' stop-color='#bbb' stop-opacity='.1'/><stop offset='1' stop-opacity='.1'/></linearGradient><mask id='a'><rect width='108' height='20' rx='3' fill='#fff'/></mask><g mask='url(#a)'><path fill='#555' d='M0 0h40v20H0z'/><path fill='#007ec6' d='M40 0h68v20H40z'/><path fill='url(#b)' d='M0 0h108v20H0z'/></g><g fill='#fff' text-anchor='middle' font-family='DejaVu Sans,Verdana,Geneva,sans-serif' font-size='11'><text x='20' y='15' fill='#010101' fill-opacity='.3'>#{prefix}</text><text x='20' y='14'>#{prefix}</text><text x='73' y='15' fill='#010101' fill-opacity='.3'>Submitted</text><text x='73' y='14'>Submitted</text></g></svg>"
    when "under_review"
# @NeuroLibre
      "<svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' width='158' height='20' role='img' aria-label='#{prefix}: Under Review'><title>#{prefix}: Under Review</title><linearGradient id='s' x2='0' y2='100%'><stop offset='0' stop-color='#bbb' stop-opacity='.1'/><stop offset='1' stop-opacity='.1'/></linearGradient><clipPath id='r'><rect width='158' height='20' rx='3' fill='#fff'/></clipPath><g clip-path='url(#r)'><rect width='71' height='20' fill='#555'/><rect x='71' width='87' height='20' fill='#fe7d37'/><rect width='158' height='20' fill='url(#s)'/></g><g fill='#fff' text-anchor='middle' font-family='Verdana,Geneva,DejaVu Sans,sans-serif' text-rendering='geometricPrecision' font-size='110'><text aria-hidden='true' x='365' y='150' fill='#010101' fill-opacity='.3' transform='scale(.1)' textLength='610'>#{prefix}</text><text x='365' y='140' transform='scale(.1)' fill='#fff' textLength='610'>#{prefix}</text><text aria-hidden='true' x='1135' y='150' fill='#010101' fill-opacity='.3' transform='scale(.1)' textLength='770'>Under Review</text><text x='1135' y='140' transform='scale(.1)' fill='#fff' textLength='770'>Under Review</text></g></svg>"
    when "review_completed"
      "<svg xmlns='http://www.w3.org/2000/svg' width='150' height='20'><linearGradient id='b' x2='0' y2='100%'><stop offset='0' stop-color='#bbb' stop-opacity='.1'/><stop offset='1' stop-opacity='.1'/></linearGradient><mask id='a'><rect width='150' height='20' rx='3' fill='#fff'/></mask><g mask='url(#a)'><path fill='#555' d='M0 0h40v20H0z'/><path fill='#dfb317' d='M40 0h110v20H40z'/><path fill='url(#b)' d='M0 0h150v20H0z'/></g><g fill='#fff' text-anchor='middle' font-family='DejaVu Sans,Verdana,Geneva,sans-serif' font-size='11'><text x='20' y='15' fill='#010101' fill-opacity='.3'>#{prefix}</text><text x='20' y='14'>#{prefix}</text><text x='94' y='15' fill='#010101' fill-opacity='.3'>Review Complete</text><text x='94' y='14'>Review Complete</text></g></svg>"
    when "accepted"
# @NeuroLibre
      "<svg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' width='220' height='20' role='img' aria-label='#{prefix}: #{self.doi}'><title>NeuroLibre: #{self.doi}</title><linearGradient id='s' x2='0' y2='100%'><stop offset='0' stop-color='#bbb' stop-opacity='.1'/><stop offset='1' stop-opacity='.1'/></linearGradient><clipPath id='r'><rect width='220' height='20' rx='3' fill='#fff'/></clipPath><g clip-path='url(#r)'><rect width='71' height='20' fill='#555'/><rect x='71' width='149' height='20' fill='#4c1'/><rect width='220' height='20' fill='url(#s)'/></g><g fill='#fff' text-anchor='middle' font-family='Verdana,Geneva,DejaVu Sans,sans-serif' text-rendering='geometricPrecision' font-size='110'><text aria-hidden='true' x='365' y='150' fill='#010101' fill-opacity='.3' transform='scale(.1)' textLength='610'>#{prefix}</text><text x='365' y='140' transform='scale(.1)' fill='#fff' textLength='610'>NeuroLibre</text><text aria-hidden='true' x='1445' y='150' fill='#010101' fill-opacity='.3' transform='scale(.1)' textLength='1390'>#{self.doi}</text><text x='1445' y='140' transform='scale(.1)' fill='#fff' textLength='1390'>#{self.doi}</text></g></svg>"
    when "rejected"
      "<svg xmlns='http://www.w3.org/2000/svg' width='100' height='20'><linearGradient id='b' x2='0' y2='100%'><stop offset='0' stop-color='#bbb' stop-opacity='.1'/><stop offset='1' stop-opacity='.1'/></linearGradient><mask id='a'><rect width='100' height='20' rx='3' fill='#fff'/></mask><g mask='url(#a)'><path fill='#555' d='M0 0h40v20H0z'/><path fill='#e05d44' d='M40 0h60v20H40z'/><path fill='url(#b)' d='M0 0h100v20H0z'/></g><g fill='#fff' text-anchor='middle' font-family='DejaVu Sans,Verdana,Geneva,sans-serif' font-size='11'><text x='20' y='15' fill='#010101' fill-opacity='.3'>#{prefix}</text><text x='20' y='14'>#{prefix}</text><text x='69' y='15' fill='#010101' fill-opacity='.3'>Rejected</text><text x='69' y='14'>Rejected</text></g></svg>"
    when "retracted"
      "<svg xmlns='http://www.w3.org/2000/svg' width='100' height='20'><linearGradient id='b' x2='0' y2='100%'><stop offset='0' stop-color='#bbb' stop-opacity='.1'/><stop offset='1' stop-opacity='.1'/></linearGradient><mask id='a'><rect width='100' height='20' rx='3' fill='#fff'/></mask><g mask='url(#a)'><path fill='#555' d='M0 0h40v20H0z'/><path fill='#e05d44' d='M40 0h60v20H40z'/><path fill='url(#b)' d='M0 0h100v20H0z'/></g><g fill='#fff' text-anchor='middle' font-family='DejaVu Sans,Verdana,Geneva,sans-serif' font-size='11'><text x='20' y='15' fill='#010101' fill-opacity='.3'>#{prefix}</text><text x='20' y='14'>#{prefix}</text><text x='69' y='15' fill='#010101' fill-opacity='.3'>Rejected</text><text x='69' y='14'>Retracted</text></g></svg>"
    else
      "<svg xmlns='http://www.w3.org/2000/svg' width='102' height='20'><linearGradient id='b' x2='0' y2='100%'><stop offset='0' stop-color='#bbb' stop-opacity='.1'/><stop offset='1' stop-opacity='.1'/></linearGradient><mask id='a'><rect width='102' height='20' rx='3' fill='#fff'/></mask><g mask='url(#a)'><path fill='#555' d='M0 0h40v20H0z'/><path fill='#9f9f9f' d='M40 0h62v20H40z'/><path fill='url(#b)' d='M0 0h102v20H0z'/></g><g fill='#fff' text-anchor='middle' font-family='DejaVu Sans,Verdana,Geneva,sans-serif' font-size='11'><text x='20' y='15' fill='#010101' fill-opacity='.3'>#{prefix}</text><text x='20' y='14'>#{prefix}</text><text x='70' y='15' fill='#010101' fill-opacity='.3'>Unknown</text><text x='70' y='14'>Unknown</text></g></svg>"
    end
  end

  def status_badge_url
    # @NeuroLibre
    "#{Rails.application.settings["url"]}/papers/#{Rails.application.settings[:doi_prefix]}/#{joss_id}/status.svg"
  end

  def markdown_code
    "[![DOI](#{status_badge_url})](https://doi.org/#{doi})"
  end

  # Extract GitHub issue number from NeuroLibre DOI format
  # e.g., "10.55458/neurolibre.00027" -> 27
  def extract_issue_number_from_doi(doi_string)
    return nil if doi_string.blank?

    doi_prefix = Rails.application.settings[:doi_prefix]
    doi_suffix_name = Rails.application.settings[:abbreviation].downcase
    regex = /#{Regexp.escape(doi_prefix)}\/#{Regexp.escape(doi_suffix_name)}\.(\d{5})/
    match = doi_string.match(regex)
    match ? match[1].to_i : nil
  end

  # Check if this paper is a resubmission with valid existing DOI
  def is_resubmission_with_doi?
    submission_kind == 'resubmission' && published_parent_doi.present?
  end

  # Get the GitHub issue number from existing submission DOI
  def existing_github_issue_number
    return nil unless is_resubmission_with_doi?
    extract_issue_number_from_doi(published_parent_doi)
  end

  # Check the status of the existing GitHub issue
  def existing_github_issue_status
    issue_number = existing_github_issue_number
    return { status: :no_issue_number } if issue_number.nil?

    begin
      issue = GITHUB.issue(Rails.application.settings["reviews"], issue_number)
      {
        status: issue.state.to_sym, # :open or :closed
        title: issue.title,
        number: issue_number
      }
    rescue Octokit::NotFound
      { status: :not_found, number: issue_number }
    rescue => e
      Rails.logger.error "Error checking GitHub issue #{issue_number}: #{e.message}"
      { status: :error, number: issue_number, error: e.message }
    end
  end

  # Check if the GitHub issue can be reopened
  def can_reopen_github_issue?
    return false unless is_resubmission_with_doi?

    issue_status = existing_github_issue_status
    issue_status[:status] == :closed
  end

  # Detect the next preprint version by checking existing PDF files
  # in the neurolibre/preprints repository
  def detect_next_preprint_version
    issue_number = existing_github_issue_number
    return "v2" if issue_number.nil?

    # Format the issue number with leading zeros (e.g., 00023)
    formatted_issue = "%05d" % issue_number
    doi_prefix = "#{Rails.application.settings["doi_prefix"]}.neurolibre.#{formatted_issue}"

    begin
      # List all files in the master branch of neurolibre/preprints
      contents = GITHUB.contents("neurolibre/preprints", path: "", ref: "master")

      # Filter files that match the DOI pattern
      matching_files = contents.select do |file|
        file.name.start_with?(doi_prefix) && file.name.end_with?(".pdf")
      end

      if matching_files.empty?
        # No files found, shouldn't happen for resubmissions but default to v2
        Rails.logger.warn "No existing preprint files found for #{doi_prefix}, defaulting to v2"
        return "v2"
      end

      # Check if files have version suffixes
      versioned_files = matching_files.select do |file|
        # Match pattern: 10.55458.neurolibre.00023.v1.pdf, v2.pdf, etc.
        doi_prefix = "#{Rails.application.settings["doi_prefix"]}.neurolibre.#{formatted_issue}"
        file.name.match(/\.v(\d+)\.pdf$/)
      end

      if versioned_files.empty?
        # Files exist without version suffix (e.g., 10.55458.neurolibre.00023.pdf)
        doi_prefix = "#{Rails.application.settings["doi_prefix"]}.neurolibre.#{formatted_issue}"
        # This means only v1 exists, so next version is v2
        return "v2"
      else
        # Extract version numbers and find the highest
        version_numbers = versioned_files.map do |file|
          match = file.name.match(/\.v(\d+)\.pdf$/)
          match[1].to_i
        end

        highest_version = version_numbers.max
        next_version = highest_version + 1
        return "v#{next_version}"
      end

    rescue Octokit::NotFound
      Rails.logger.error "Repository neurolibre/preprints or path not found"
      return "v2"
    rescue => e
      Rails.logger.error "Error detecting preprint version: #{e.message}"
      return "v2"
    end
  end

  # Update the preprint version in the GitHub issue body
  def update_issue_preprint_version(issue_number, new_version)
    begin
      # Get the current issue
      issue = GITHUB.issue(Rails.application.settings["reviews"], issue_number)
      current_body = issue.body

      # Update the preprint version using regex
      updated_body = current_body.gsub(
        /(?<=<!--preprint-version-->).*?(?=<!--end-preprint-version-->)/,
        new_version
      )

      # Update the issue body
      GITHUB.update_issue(Rails.application.settings["reviews"], issue_number, body: updated_body)

      Rails.logger.info "Updated preprint version to #{new_version} in issue ##{issue_number}"
      { success: true, version: new_version }
    rescue => e
      Rails.logger.error "Error updating preprint version in issue #{issue_number}: #{e.message}"
      { success: false, error: e.message }
    end
  end

  # Reopen the existing GitHub issue
  def reopen_github_issue
    issue_number = existing_github_issue_number
    return { success: false, error: "No issue number found" } if issue_number.nil?

    begin
      # Detect the next preprint version
      next_version = detect_next_preprint_version

      # Reopen the issue
      GITHUB.reopen_issue(Rails.application.settings["reviews"], issue_number)

      # Remove old labels
      labels_to_remove = ["accepted", "recommend-accept", "published", "review"]
      labels_to_remove.each do |label|
        begin
          GITHUB.remove_label(Rails.application.settings["reviews"], issue_number, label)
        rescue Octokit::NotFound
          # Label doesn't exist on the issue, continue
        end
      end

      # Add new labels
      labels_to_add = ["reopened", "new-version"]
      labels_to_add << self.track.label if self.track.present?
      GITHUB.add_labels_to_an_issue(Rails.application.settings["reviews"], issue_number, labels_to_add)

      # Update the preprint version in the issue body
      version_result = update_issue_preprint_version(issue_number, next_version)

      # Add a comment explaining the resubmission
      comment_body = "This issue has been reopened for a resubmission.\n\n" \
                     "**Original DOI:** #{published_parent_doi}\n" \
                     "**New Submission:** #{title}\n" \
                     "**Repository:** #{repository_url}\n" \
                     "**Preprint Version:** #{next_version}\n\n" \
                     "Please review the updated submission."

      GITHUB.add_comment(Rails.application.settings["reviews"], issue_number, comment_body)

      Rails.logger.info "Successfully reopened GitHub issue ##{issue_number} for paper #{id} with version #{next_version}"
      { success: true, issue_number: issue_number, version: next_version }
    rescue => e
      Rails.logger.error "Error reopening GitHub issue #{issue_number}: #{e.message}"
      { success: false, error: e.message }
    end
  end

private

  def check_repository_address
    stdout_str, stderr_str, status = Open3.capture3("git ls-remote #{repository_url}")

    if !status.success?
      errors.add(:base, :invalid, message: "Invalid Git repository address. Check that the repository can be cloned using the value entered in the form, and that access doesn't require authentication.")
      return false
    end
  end

  def set_sha
    self.sha ||= SecureRandom.hex
  end

  def set_last_activity
    self.last_activity = Time.now
  end
end
