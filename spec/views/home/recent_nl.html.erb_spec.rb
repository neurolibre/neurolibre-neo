require "rails_helper"

describe "home/_recent_nl.html.erb", type: :view do
  let(:archives) do
    { book_doi: "https://doi.org/10.5281/zenodo.1", data_doi: "https://doi.org/10.5281/zenodo.2",
      repository_doi: "https://doi.org/10.5281/zenodo.3", docker_doi: "https://doi.org/10.5281/zenodo.4",
      book_exec_url: "https://preprint.neurolibre.org/10.55458/neurolibre.00001" }
  end
  let(:newest) { build(:accepted_paper, title: "The newest preprint", doi: "10.55458/neurolibre.00002", accepted_at: 1.day.ago, **archives) }
  let(:older) { build(:accepted_paper, title: "An older preprint", doi: "10.55458/neurolibre.00001", accepted_at: 10.days.ago, data_doi: "https://doi.org/10.5281/zenodo.9") }

  before do
    allow(view).to receive(:prefetch_card_images)
    allow(view).to receive(:pretty_card_image).and_return("https://example.org/featured.png")
    render partial: "home/recent_nl", locals: { papers: [newest, older] }
  end

  let(:doc) { Nokogiri::HTML(rendered) }

  it "features the newest paper and lists the rest in the grid" do
    expect(doc.at_css(".nl-recent__featured h3").text.squish).to eq("The newest preprint")
    expect(doc.css(".nl-recent__card h3").map { |h| h.text.squish }).to eq(["An older preprint"])
  end

  it "links each archive chip to the paper's archive DOI, in layer order" do
    chips = doc.css(".nl-recent__featured .nl-recent__chip")
    expect(chips.map { |c| c.text.squish }).to eq(%w[Prose Data Code Runtime])
    expect(chips.map { |c| c["href"] }).to eq(archives.values_at(:book_doi, :data_doi, :repository_doi, :docker_doi))
  end

  it "only shows the archives a paper has" do
    expect(doc.css(".nl-recent__card .nl-recent__dot").map { |d| d["title"] }).to eq(["Data"])
  end

  it "opens the living preprint, and links to all papers with the count" do
    expect(doc.at_css(".nl-recent__featured .nl-recent__open")["href"]).to eq(archives[:book_exec_url])
    expect(doc.at_css(".nl-recent__all")["href"]).to eq(published_papers_path)
    expect(doc.at_css(".nl-recent__all").text).to include(Paper.visible.count.to_s)
  end
end
