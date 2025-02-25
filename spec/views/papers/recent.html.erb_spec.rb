require 'rails_helper'

describe 'papers/recent.html.erb' do
  before { skip_paper_repo_url_check }

  context 'for recent papers' do
    it "should show the correct number of papers" do
      user = create(:user)
      3.times do
        create(:accepted_paper, submitting_author: user)
      end

      assign(:papers, Paper.all.paginate(page: 1, per_page: 10))

      render template: "papers/index", formats: :html

      expect(rendered).to have_selector('.paper-title', count: 3)
      expect(rendered).to have_content(:visible, "Published Papers 3", normalize_ws: true)
    end
  end
end
