# NeuroLibre-only helpers for the home page's recent papers (home/_recent_nl).
# Kept out of upstream helpers so upstream changes merge cleanly.
module NeurolibreRecentHelper
  # A paper's reproducibility artifacts, each with the archive DOI it links
  # to and the icon the old cards used. Only archives the paper has are
  # returned ("N/A" counts as none, as in PapersHelper#pretty_archive_badge).
  NL_RECENT_LAYERS = [
    [:html, "HTML", :book_doi, %w[fa-solid file-code]],
    [:data, "Data", :data_doi, %w[fa-solid database]],
    [:code, "Code", :repository_doi, %w[fa-brands github]],
    [:runtime, "Runtime", :docker_doi, %w[fa-brands docker]]
  ].freeze

  def nl_recent_layers(paper)
    NL_RECENT_LAYERS.filter_map do |kind, label, field, icon|
      url = paper.public_send(field)
      { kind: kind, label: label, url: url, icon: icon } if url.present? && url != "N/A"
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
