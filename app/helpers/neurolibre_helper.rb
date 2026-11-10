require "net/http"

module NeurolibreHelper

    # This method returns an html safe URL for the reproducible preprint (preprint.neurolibre.org/)
    def pretty_book_link(input_url)
        return input_url.scan(/"([^"]*)"/).join(', ').html_safe
    end

# This method operates on a (class) paper instance variable (not a random input).
# When added at the root directory of a NeuroLibre submission repository, `featured.png`
# (or .jpg, .jpeg, .webp, .tiff) is displayed in the paper card.
# It checks the main and master branches, otherwise returns a placeholder.
#
# The answer for each repository is remembered for CARD_IMAGE_TTL, so the home
# page no longer sends up to 10 requests to GitHub per card on every visit, and
# the candidates are checked in parallel the first time.
    CARD_IMAGE_EXTENSIONS = %w[png jpg jpeg webp tiff].freeze
    CARD_IMAGE_FALLBACK = "https://raw.githubusercontent.com/neurolibre/brand/main/png/pattern_dark.png".freeze
    CARD_IMAGE_TTL = 12.hours
    CARD_IMAGE_CACHE = Concurrent::Map.new

    def self.clear_card_image_cache!
        CARD_IMAGE_CACHE.clear
    end

    def pretty_card_image(paper)
        repo_name = paper.pretty_repository_name.gsub(/\s+/, "")
        cached = CARD_IMAGE_CACHE[repo_name]
        return cached[:url] if cached && cached[:at] > CARD_IMAGE_TTL.ago

        url = find_card_image(repo_name)
        CARD_IMAGE_CACHE[repo_name] = { url: url, at: Time.current }
        url
    end

    # Look up every card in a list at the same time, so a cold cache costs
    # about one lookup's time rather than one per paper.
    def prefetch_card_images(papers)
        papers.map { |paper| Thread.new { pretty_card_image(paper) } }.each(&:join)
        nil
    end

    # Candidates in order of preference: for each extension, main before master.
    def find_card_image(repo_name)
        candidates = CARD_IMAGE_EXTENSIONS.flat_map do |ext|
            %w[main master].map { |branch| "https://raw.githubusercontent.com/#{repo_name}/#{branch}/featured.#{ext}" }
        end
        found = candidates.map { |url| Thread.new { url_exist?(url) } }.map(&:value)
        first = found.index(true)
        first ? candidates[first] : CARD_IMAGE_FALLBACK
    end

    # This method populates the paper card with author information 
    # Depending on the existence of the authors data and links 
    # per author (e.g., personal webpage etc.)
    def pretty_authors_card(authors)
        if authors.nil?
          return "".html_safe
        else
          fragment = []
          authors.each do |author|
            fragment << author_link_card(author)
          end
    
          return fragment.join(', ').html_safe
        end
    end
    
    def author_link_card(author)
        name = "#{author['given_name']} #{author['middle_name']} #{author['last_name']}".squish
        return name
    end

    # This method checks whether a provided URL exists.
    # Handles cant found cases both for the content (404) and server.
    def url_exist?(url_string)
        url = URI.parse(url_string)
        req = Net::HTTP.new(url.host, url.port)
        req.use_ssl = (url.scheme == 'https')
        req.open_timeout = 2
        req.read_timeout = 2
        path = url.path if url.path.present?
        res = req.request_head(path || '/')
        res.code != "404" # false if returns 404 - not found
      rescue StandardError
        false # no server, a timeout, or any other network error: treat as no image
    end

    def doi_helper_nl(input_doi)
      return "DOI pending" unless input_doi
      bare_doi = input_doi[/\b(10[.][0-9]{4,}(?:[.][0-9]+)*\/(?:(?!["&\'<>])\S)+)\b/]
      if input_doi.include?("https://doi.org/")
        return input_doi.gsub(/\"/, "")
      elsif bare_doi
        return "https://doi.org/#{bare_doi}".gsub(/\"/, "")
      else
        return input_doi.gsub(/\"/, "")
      end
    end

end