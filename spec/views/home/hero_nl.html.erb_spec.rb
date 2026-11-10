require "rails_helper"

describe "home/_hero_nl.html.erb", type: :view do
  before { render partial: "home/hero_nl" }

  let(:doc) { Nokogiri::HTML(rendered) }

  it "shows the headline and the reproducibility statement" do
    expect(doc.at_css("h1.nl-hero__title").text.squish).to eq("More than a PDF")
    expect(rendered).to include("A NeuroLibre preprint packages the article together with its reproducibility artifacts.")
    expect(rendered).to include("Checked that it runs before it is published")
    expect(rendered).to include("A NeuroLibre preprint is a record of research that can be traced back to its sources and reproduced from them.")
  end

  it "links to submission and to the papers" do
    expect(doc.at_css("a.nl-hero__btn--primary")["href"]).to eq(new_paper_path)
    expect(doc.at_css("a.nl-hero__btn--ghost")["href"]).to eq(papers_path)
  end

  it "draws the five layers, with the NeuroLibre wordmark on the article" do
    layers = doc.css(".nl-hero__plate").map { |p| p["class"][/nl-hero__plate--(\w+)/, 1] }
    expect(layers).to eq(%w[runtime code data prose article])
    expect(doc.at_css(".nl-hero__article-head img")["src"]).to match(/joss2.*\.svg/)
  end

  it "is fitted to the window by the nl-hero controller" do
    expect(doc.at_css("section.nl-hero")["data-controller"]).to eq("nl-hero")
    expect(doc.at_css(".nl-hero__copy")["data-nl-hero-target"]).to eq("copy")
  end

  it "ties the layers together with strings while Start submission is hovered or focused" do
    action = doc.at_css("a.nl-hero__btn--primary")["data-action"]
    expect(action).to include("mouseenter->nl-hero#pack", "mouseleave->nl-hero#unpack", "focus->nl-hero#pack", "blur->nl-hero#unpack")
    expect(doc.css(".nl-hero__stack .nl-hero__strings .nl-hero__str").size).to eq(11)
    expect(doc.css(".nl-hero__bow path").size).to eq(5)
  end

  it "labels the four layer colours in the legend" do
    expect(doc.css(".nl-hero__legend li").map { |li| li.text.squish }).to eq(%w[Prose Data Code Runtime])
  end

  it "renders the same particles on every request" do
    first = doc.css(".nl-hero__dot").map { |d| d["style"] }
    second = Nokogiri::HTML(view.render(partial: "home/hero_nl")).css(".nl-hero__dot").map { |d| d["style"] }
    expect(first.size).to eq(56)
    expect(second).to eq(first)
  end
end
