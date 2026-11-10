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

  it "links each reproducibility artifact to its archive DOI, opening in a new tab" do
    artifacts = doc.at_css(".nl-recent__featured .nl-recent__artifacts")
    expect(artifacts.text).to include("Reproducibility artifacts")
    links = artifacts.css("a")
    expect(links.map { |a| a.text.squish }).to eq(%w[HTML Data Code Runtime])
    expect(links.map { |a| a["href"] }).to eq(archives.values_at(:book_doi, :data_doi, :repository_doi, :docker_doi))
    expect(links.map { |a| a["target"] }.uniq).to eq(["_blank"])
    expect(links.map { |a| a.at_css("svg, i") }).to all(be_present)
  end

  it "shows a card's artifacts as icon links, only the ones the paper has" do
    links = doc.css(".nl-recent__card .nl-recent__artifacts a")
    expect(links.map { |a| a["aria-label"] }).to eq(["Data archive"])
    expect(links.first["href"]).to eq("https://doi.org/10.5281/zenodo.9")
    expect(links.first["target"]).to eq("_blank")
  end

  it "shows each card's DOI, and opens the paper page in a new tab when the card is clicked" do
    card = doc.at_css(".nl-recent__card")
    expect(card.at_css(".nl-recent__doi").text).to include("10.55458/neurolibre.00001")
    link = card.at_css("h3 a")
    expect(link["href"]).to eq(older.seo_url)
    expect(link["target"]).to eq("_blank")
    expect(link["class"]).to include("nl-recent__stretch")
    expect(card.text).not_to include("Open →")
  end

  it "treats N/A as no archive" do
    paper = build(:accepted_paper, data_doi: "N/A", docker_doi: "N/A")
    expect(view.nl_recent_layers(paper).map { |l| l[:kind] }).to eq([])
  end

  it "opens the living preprint, and links to all papers with the count" do
    expect(doc.at_css(".nl-recent__featured .nl-recent__open")["href"]).to eq(archives[:book_exec_url])
    expect(doc.at_css(".nl-recent__all")["href"]).to eq(published_papers_path)
    expect(doc.at_css(".nl-recent__all").text).to include(Paper.visible.count.to_s)
  end
end
