# NeuroLibre-only helpers for the home page's recent papers (home/_recent_nl).
# Kept out of upstream helpers so upstream changes merge cleanly.
module NeurolibreRecentHelper
  # A paper's archives as layers, in the hero's order, each with the DOI it
  # links to. Only archives the paper has are returned.
  NL_RECENT_LAYERS = [
    [:prose, "Prose", :book_doi],
    [:data, "Data", :data_doi],
    [:code, "Code", :repository_doi],
    [:runtime, "Runtime", :docker_doi]
  ].freeze

  def nl_recent_layers(paper)
    NL_RECENT_LAYERS.filter_map do |kind, label, field|
      url = paper.public_send(field)
      { kind: kind, label: label, url: url } if url.present?
    end
  end

  def nl_recent_author_names(paper)
    (paper.metadata_authors || []).map { |a| [a["given_name"], a["last_name"]].compact_blank.join(" ") }
  end

  # "Plante, Karakuzu, Qadi et al." for the grid cards.
  def nl_recent_authors_short(paper, count = 3)
    last_names = (paper.metadata_authors || []).map { |a| a["last_name"] }.compact_blank
    return last_names.join(", ") if last_names.size <= count
    "#{last_names.first(count).join(', ')} et al."
  end

  def nl_recent_date(paper)
    paper.accepted_at&.strftime("%-d %b %Y")
  end

  # The executable preprint when there is one, otherwise the paper's page.
  def nl_recent_open_url(paper)
    paper.book_exec_url.presence || paper.seo_url
  end
end
