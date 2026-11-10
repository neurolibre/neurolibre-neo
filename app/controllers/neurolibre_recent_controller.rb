# NeuroLibre-only: the "Load more" pages of the home page's recent papers.
# The home page shows the newest FIRST_PAGE papers; each further page is the
# next PER_PAGE, returned inside a Turbo Frame that replaces the button.
class NeurolibreRecentController < ApplicationController
  FIRST_PAGE = 10
  PER_PAGE = 9

  def index
    page = [params[:page].to_i, 2].max
    offset = FIRST_PAGE + (page - 2) * PER_PAGE
    papers = Paper.unscoped.visible.order(accepted_at: :desc).offset(offset).limit(PER_PAGE + 1).to_a
    render partial: "home/recent_nl/page",
           locals: { papers: papers.first(PER_PAGE), page: page, more: papers.size > PER_PAGE }
  end
end
