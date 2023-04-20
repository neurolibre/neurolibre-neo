require "net/http"

module NeurolibreHelper


    def pretty_book_link(input_url)
        # This method returns an html safe URL for the reproducible preprint (preprint.neurolibre.org/)
        return input_url.scan(/"([^"]*)"/).join(', ').html_safe
    end

    def pretty_card_image(paper)
        # This method operates on a (class) paper instance variable (not a random input).
        # When added at the root directory of a NeuroLibre submission repository, `featured.png`
        # is displayed in the paper card.
        # This method checks whether it exists on master/main branch, otherwise returns a placeholder.
        repo_name = paper.pretty_repository_name.gsub(/\s+/, "")
        user_image_main = "https://raw.githubusercontent.com/#{repo_name}/main/featured.png"
        user_image_master = "https://raw.githubusercontent.com/#{repo_name}/master/featured.png"
        if url_exist?(user_image_main)
          return user_image_main
        elsif url_exist?(user_image_master)
          return user_image_master
        else
          return "https://raw.githubusercontent.com/neurolibre/brand/main/png/pattern_dark.png"
        end
        
    end

    def pretty_authors_card(authors)
        # This method populates the paper card with author information 
        # Depending on the existence of the authors data and links 
        # per author (e.g., personal webpage etc.)
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

    def url_exist?(url_string)
        # This method checks whether a provided URL exists.
        # Handles cant found cases both for the content (404) and server.
        url = URI.parse(url_string)
        req = Net::HTTP.new(url.host, url.port)
        req.use_ssl = (url.scheme == 'https')
        path = url.path if url.path.present?
        res = req.request_head(path || '/')
        res.code != "404" # false if returns 404 - not found
      rescue Errno::ENOENT
        false # false if can't find the server
    end

end