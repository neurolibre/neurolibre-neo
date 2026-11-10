require "net/http"

# NeuroLibre-only: links from a paper's page to what is built from it after
# publication, its Sakiori walk and its crosswalks (the paper's data described
# for agents, as FAIR² and Croissant). Both are listed in the public CDN's
# index.json, which is read once and remembered for EVIDENCE_INDEX_TTL (a
# failed read for EVIDENCE_RETRY, so a CDN outage does not slow every page).
module NeurolibreEvidenceHelper
  EVIDENCE_CDN = "https://cdn.evidencepub.io".freeze
  SAKIORI_URL = "https://sakiori.evidencepub.io".freeze
  EVIDENCE_INDEX_TTL = 12.hours
  EVIDENCE_RETRY = 10.minutes
  EVIDENCE_INDEX_CACHE = Concurrent::Map.new
  NL_CROSSWALKS = [["fair2", "FAIR²"], ["croissant", "Croissant"]].freeze

  def self.clear_evidence_index_cache!
    EVIDENCE_INDEX_CACHE.clear
  end

  # { sakiori: url, crosswalks: [{ label:, url: }] } for a paper in the CDN's
  # index, or nil when it is not there (or the index could not be read).
  def nl_evidence(paper)
    entry = nl_evidence_index[paper.doi.to_s]
    return nil unless entry

    number = paper.doi.to_s[/\d{5}\z/]
    crosswalks = entry["crosswalks"] || {}
    {
      sakiori: number && "#{SAKIORI_URL}/#{number}",
      crosswalks: NL_CROSSWALKS.filter_map do |key, label|
        path = crosswalks[key]
        { label: label, url: "#{EVIDENCE_CDN}/#{path}" } if path.present?
      end
    }
  end

  def nl_evidence_index
    cached = EVIDENCE_INDEX_CACHE[:index]
    return cached[:papers] if cached && cached[:at] > (cached[:papers].empty? ? EVIDENCE_RETRY : EVIDENCE_INDEX_TTL).ago

    papers = nl_fetch_evidence_index
    EVIDENCE_INDEX_CACHE[:index] = { papers: papers, at: Time.current }
    papers
  end

  def nl_fetch_evidence_index
    uri = URI("#{EVIDENCE_CDN}/index.json")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 2, read_timeout: 3) { |http| http.get(uri.path) }
    return {} unless response.is_a?(Net::HTTPSuccess)

    JSON.parse(response.body)["papers"] || {}
  rescue StandardError
    {} # no network, a timeout or a bad file: the page is shown without these links
  end
end
