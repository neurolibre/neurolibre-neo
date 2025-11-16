module PapersHelper
  def selected_class(tab_name)
    if controller.action_name == tab_name
      "selected"
    end
  end

  def paper_kind(paper)
    case paper.submission_kind
    when "new"
      "New submission"
    when "resubmission"
      "Resubmission"
    when "new version"
      "New version"
    else
      "Unknown"
    end
  end

  def vote_comment_preview(vote)
    return "No comment" if vote.comment.empty?

    capture do
      concat(content_tag(:span, class: "comment-preview", title: vote.comment) do
        truncate(vote.comment)
      end)
    end
  end

  def paper_count_for(user)
    user.papers.visible.count
  end

  def scholar_author_tags(authors)
    authors = authors.split(',')
    returned = ""
    authors.each do |author|
      returned << "<meta name=\"citation_author\" content=\"#{author.strip}\">\n"
    end

    returned.html_safe
  end

  def pretty_reviewers(reviewers)
    fragment = []
    reviewers.each do |reviewer|
      fragment << github_link(reviewer) + " (" + reviewer_page_link('all reviews', reviewer) + ")"
    end

    return fragment.join(', ').html_safe
  end

  def reviewer_page_link(link_text, handle)
    link_to link_text, papers_by_reviewer_path(handle), title: "All papers reviewed by #{handle}"
  end

  def github_link(handle)
    link_to handle, "https://github.com/#{handle.gsub(/^\@/, "")}", title: "GitHub profile for #{handle}", target: "_blank"
  end

  def pretty_authors(authors)
    fragment = []
    authors.each do |author|
      fragment << author_link(author)
    end

    return fragment.join(', ').html_safe
  end

  def author_link(author)
    name = "#{author['given_name']} #{author['middle_name']} #{author['last_name']}".squish
    author_search_link = link_to(name, "/papers/by/#{name}".gsub('.', '%2E'))

    if author['orcid']
      orcid_link = link_to author['orcid'], "http://orcid.org/#{author['orcid']}", target: "_blank"
      return "#{author_search_link} (#{orcid_link})"
    else
      return author_search_link
    end
  end

  def pretty_status_badge(paper)
    state = paper.state.gsub('_', ' ')
    badge_class = paper.state.gsub('_', '-')

    if state == "accepted"
      return content_tag(:span, "LIVING PREPRINT", class: "badge #{badge_class}")
    else
      return content_tag(:span, state, class: "badge #{badge_class}")
    end

  end

  def pretty_archive_badge(paper)
    state = paper.state.gsub('_', ' ')

    github_badge = paper.repository_doi ? link_to(content_tag(:span, icon('fa-brands', 'github'), class: "badge github"), paper.repository_doi,target: "_blank") : ""
    book_badge = paper.book_doi ? link_to(content_tag(:span, icon('fa-solid', 'file-code'), class: "badge book"), paper.book_doi,target: "_blank") : ""
    data_badge = (paper.data_doi && paper.data_doi != "N/A") ? link_to(content_tag(:span, icon('fa-solid', 'database'), class: "badge data"), paper.data_doi,target: "_blank") : ""
    docker_badge = (paper.docker_doi && paper.docker_doi != "N/A") ? link_to(content_tag(:span, icon('fa-brands', 'docker'), class: "badge docker"), paper.docker_doi,target: "_blank") : ""
    if state == "accepted"
    return safe_join([github_badge,book_badge,data_badge,docker_badge],' ')
    end
  end

  def pretty_prpub_badge(paper)
    state = paper.state.gsub('_', ' ')

    prpub_badge = paper.prpub_doi ? link_to(content_tag(:span, paper.prpub_journal, class: "badge peer-review"), paper.prpub_doi,target: "_blank") : ""
    if state == "accepted"
      if paper.prpub_doi
        return safe_join([" ",prpub_badge],' ')
      else
        return ""
      end
    end
  end

  def time_words(paper)
    case paper.state
    when "accepted"
      return content_tag(:span, "Published #{time_ago_in_words(paper.accepted_at)} ago", class: "time")
    else
      return content_tag(:span, "Submitted #{time_ago_in_words(paper.created_at)} ago", class: "time")
    end
  end

  def badge_link(paper)
    if paper.accepted?
      return paper.cross_ref_doi_url
    elsif paper.review_pending?
      return paper.meta_review_url
    else
      return paper.review_url
    end
  end

  def submittor_avatar(paper)
    if username = paper.submitting_author.github_username
      return "https://github.com/#{username.sub(/^@/, "")}.png"
    else
      return ""
    end
  end

  def submittor_github(paper)
    if username = paper.submitting_author.github_username
      return "https://github.com/#{username.sub(/^@/, "")}"
    else
      return "https://github.com"
    end
  end

  def formatted_body(paper, length=nil)
    pipeline = HTML::Pipeline.new [
      HTML::Pipeline::MarkdownFilter,
      HTML::Pipeline::SanitizationFilter
    ]

    if length
      body = paper.body.truncate(length, separator: /\s/)
    else
      body = paper.body
    end

    result = pipeline.call(body)
    result[:output].to_s.html_safe
  end

  def paper_types
    Rails.application.settings["paper_types"]
  end

  def open_invites_for_paper(paper)
    output = []
    @pending_invitations.each do |invite|
      if invite.paper_id == paper.id
        output << link_to(image_tag(avatar(invite.editor.login), size: "24x24", class: "avatar", title: "#{invite.editor.full_name} invited #{time_ago_in_words(invite.created_at)} ago"), paper.meta_review_url)
      end
    end

    return output.empty? ? "–" : output.join(" • ").html_safe
  end

  def pretty_version_badge(paper)
    return "" unless paper.version

    # Extract version number (e.g., "v2" -> 2)
    version_num = paper.version.gsub(/[^0-9]/, '').to_i

    # Only show badge for versions greater than v1
    return "" if version_num <= 1

    content_tag(:span, paper.version.upcase, class: "badge badge-version", title: "Paper version")
  end

  # FAIR Signposting helpers
  # Generate a single signposting <link> element
  def signposting_link_tag(rel:, href:, type: nil, profile: nil)
    return "" if href.blank?

    attrs = { rel: rel, href: href }
    attrs[:type] = type if type.present?
    attrs[:profile] = profile if profile.present?

    tag.link(**attrs)
  end

  # Generate author ORCID signposting links
  def signposting_author_links(paper)
    return "" unless paper.metadata_authors.present?

    links = []
    paper.metadata_authors.each do |author|
      if author['orcid'].present?
        orcid_url = author['orcid'].start_with?('http') ? author['orcid'] : "https://orcid.org/#{author['orcid']}"
        links << signposting_link_tag(rel: 'author', href: orcid_url)
      end
    end

    safe_join(links, "\n  ")
  end

  # Generate content resource (item) signposting links
  def signposting_item_links(paper)
    links = []

    # PDF content resource
    if paper.pdf_url.present?
      links << signposting_link_tag(rel: 'item', href: paper.pdf_url, type: 'application/pdf')
    end

    # Executable book content resource
    if paper.book_exec_url.present?
      links << signposting_link_tag(rel: 'item', href: paper.book_exec_url, type: 'text/html')
    end

    safe_join(links, "\n  ")
  end

  # Generate metadata resource (describedby) signposting links
  def signposting_metadata_links(paper)
    links = []

    # JSON metadata
    json_url = "#{paper.seo_url}.json"
    links << signposting_link_tag(rel: 'describedby', href: json_url, type: 'application/json')

    safe_join(links, "\n  ")
  end

  # Generate persistent identifier (cite-as) signposting links
  def signposting_cite_as_links(paper, canonical_doi: nil)
    links = []

    # Use canonical DOI if provided (for versioned papers), otherwise use paper's DOI
    if canonical_doi.present?
      canonical_url = "https://doi.org/#{canonical_doi}"
      links << signposting_link_tag(rel: 'cite-as', href: canonical_url)
    elsif paper.doi.present?
      links << signposting_link_tag(rel: 'cite-as', href: paper.cross_ref_doi_url)
    end

    safe_join(links, "\n  ")
  end

  # Generate resource type signposting links
  def signposting_type_links
    links = []

    # Required: AboutPage type
    links << signposting_link_tag(rel: 'type', href: 'https://schema.org/AboutPage')

    # Specific creative work type
    links << signposting_link_tag(rel: 'type', href: 'https://schema.org/ScholarlyArticle')

    safe_join(links, "\n  ")
  end

  # Generate related resource signposting links (archive DOIs)
  def signposting_related_links(paper)
    links = []

    # Repository DOI (archived code)
    if paper.repository_doi.present? && paper.repository_doi != "DOI pending"
      repo_url = Paper.doi_with_url_for(paper.repository_doi)
      links << signposting_link_tag(rel: 'related', href: repo_url)
    end

    # Book DOI (archived executable book)
    if paper.book_doi.present?
      book_url = Paper.doi_with_url_for(paper.book_doi)
      links << signposting_link_tag(rel: 'related', href: book_url)
    end

    # Data DOI (archived data)
    if paper.data_doi.present? && paper.data_doi != "N/A"
      data_url = Paper.doi_with_url_for(paper.data_doi)
      links << signposting_link_tag(rel: 'related', href: data_url)
    end

    # Docker DOI (archived compute environment)
    if paper.docker_doi.present? && paper.docker_doi != "N/A"
      docker_url = Paper.doi_with_url_for(paper.docker_doi)
      links << signposting_link_tag(rel: 'related', href: docker_url)
    end

    safe_join(links, "\n  ")
  end

  # Generate LDN inbox signposting link
  def signposting_inbox_link
    inbox_url = "https://robo.neurolibre.org/coar_notify/inbox"
    signposting_link_tag(rel: 'http://www.w3.org/ns/ldp#inbox', href: inbox_url)
  end

  # Generate version-related signposting links
  def signposting_version_links(paper, all_versions: [])
    links = []

    # Link to latest version if this is not the latest
    if all_versions.any? && !paper.latest_version?
      latest = paper.latest_version
      if latest && latest != paper
        links << signposting_link_tag(rel: 'latest-version', href: latest.seo_url)
      end
    end

    safe_join(links, "\n  ")
  end
end
