require "net/http"

# NeuroLibre-only: links from a paper's page to what the public CDN holds for
# it: its structured content (the article's MyST JSON, the page config.json
# names as the project's index), its Sakiori walk and its crosswalks (the
# paper's data described for agents, as FAIR² and Croissant, which index.json
# lists). Each file is read once and remembered for EVIDENCE_INDEX_TTL (a
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

  # The paper's article as MyST JSON on the CDN, or nil.
  def nl_structured_content_url(paper)
    project = nl_evidence_projects[paper.doi.to_s]
    return nil unless project && project["slug"].present?

    "#{EVIDENCE_CDN}/content/#{project['slug']}/#{project['index'].presence || 'index'}.json"
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
    nl_cdn_cached(:index) { |body| JSON.parse(body)["papers"] || {} }
  end

  # The MyST projects config.json lists, by DOI.
  def nl_evidence_projects
    nl_cdn_cached(:config) { |body| (JSON.parse(body)["projects"] || []).to_h { |p| [p["doi"], p] } }
  end

  def nl_cdn_cached(name)
    cached = EVIDENCE_INDEX_CACHE[name]
    return cached[:value] if cached && cached[:at] > (cached[:value].empty? ? EVIDENCE_RETRY : EVIDENCE_INDEX_TTL).ago

    body = nl_fetch_cdn("#{name}.json")
    value = begin
      body ? yield(body) : {}
    rescue StandardError
      {}
    end
    EVIDENCE_INDEX_CACHE[name] = { value: value, at: Time.current }
    value
  end

  # A file's text from the CDN, or nil when it cannot be read.
  def nl_fetch_cdn(path)
    uri = URI("#{EVIDENCE_CDN}/#{path}")
    response = Net::HTTP.start(uri.host, uri.port, use_ssl: true, open_timeout: 2, read_timeout: 4) { |http| http.get(uri.path) }
    response.is_a?(Net::HTTPSuccess) ? response.body : nil
  rescue StandardError
    nil # no network or a timeout: the page is shown without these links
  end
end
