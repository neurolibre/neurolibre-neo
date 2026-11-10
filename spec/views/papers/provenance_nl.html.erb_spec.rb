require "rails_helper"

describe "papers/_provenance_nl.html.erb", type: :view do
  let(:doc) { Nokogiri::HTML(rendered) }
  let(:steps) { doc.css(".nl-provenance__step") }
  let(:evidence) { nil }
  let(:structured) { nil }
  before do
    allow(view).to receive(:nl_evidence).and_return(evidence)
    allow(view).to receive(:nl_structured_content_url).and_return(structured)
  end

  context "with every step present" do
    let(:paper) do
      build(:accepted_paper,
            doi: "10.55458/neurolibre.00048",
            review_issue_id: 48,
            repository_url: "https://github.com/moranebienvenu/stroke_article",
            book_exec_url: "https://preprint.neurolibre.org/10.55458/neurolibre.00048",
            book_doi: "https://doi.org/10.5281/zenodo.23986173",
            data_doi: "https://doi.org/10.5281/zenodo.23986181",
            repository_doi: "https://doi.org/10.5281/zenodo.23986169",
            docker_doi: "https://doi.org/10.5281/zenodo.23986179")
    end
    before { render partial: "papers/provenance_nl", locals: { paper: paper } }

    it "lists the four steps in order, ending with Published" do
      expect(steps.map { |s| s.at_css("strong").text }).to eq(
        ["Source repository", "Technical screening", "Reproducibility artifacts", "Published"])
      expect(steps.last["class"]).to include("nl-provenance__step--done")
    end

    it "links the repository and the screening issue" do
      expect(steps[0].at_css("a")["href"]).to eq(paper.repository_url)
      expect(steps[0].text).to include("moranebienvenu/stroke_article")
      expect(steps[1].at_css("a")["href"]).to eq(paper.review_url)
      expect(steps[1].text).to include("#48")
    end

    it "links each archive in layer order" do
      links = steps[2].css(".nl-provenance__artifact")
      expect(links.map { |l| l.text.squish }).to eq(%w[HTML Data Code Runtime])
      expect(links.map { |l| l["href"] }).to eq([paper.book_doi, paper.data_doi, paper.repository_doi, paper.docker_doi])
    end

    it "ends with the paper DOI, the living preprint and the PDF" do
      expect(steps.last.at_css(".nl-provenance__doi")["href"]).to eq("https://doi.org/10.55458/neurolibre.00048")
      buttons = steps.last.css(".nl-provenance__btn")
      expect(buttons.map { |b| b.text.squish }).to eq(["Living preprint", "Download PDF"])
      expect(buttons.map { |b| b["href"] }).to eq([paper.book_exec_url, paper.pdf_url])
    end
  end

  context "without archives or a living preprint" do
    let(:paper) do
      build(:accepted_paper, review_issue_id: 12, book_exec_url: nil,
            book_doi: nil, data_doi: "N/A", repository_doi: nil, docker_doi: "N/A")
    end
    before { render partial: "papers/provenance_nl", locals: { paper: paper } }

    it "leaves those steps out and keeps the PDF" do
      expect(steps.map { |s| s.at_css("strong").text }).to eq(["Source repository", "Technical screening", "Published"])
      expect(steps.last.css(".nl-provenance__btn").map { |b| b.text.squish }).to eq(["Download PDF"])
    end
  end

  context "when the CDN lists the paper's Sakiori walk and crosswalks" do
    let(:paper) { build(:accepted_paper, doi: "10.55458/neurolibre.00048", review_issue_id: 48) }
    let(:structured) { "https://cdn.evidencepub.io/content/neurolibre-00048/index.json" }

    it "offers the structured content under the PDF" do
      published = steps.find { |s| s.at_css("strong").text == "Published" }
      buttons = published.css(".nl-provenance__btn")
      expect(buttons.map { |b| b.text.squish }.last(2)).to eq(["Download PDF", "Structured content"])
      expect(buttons.last["href"]).to eq(structured)
    end
    let(:evidence) do
      { sakiori: "https://sakiori.evidencepub.io/00048",
        crosswalks: [{ label: "FAIR²", url: "https://cdn.evidencepub.io/crosswalks/10.55458/neurolibre.00048/fair2.json" },
                     { label: "Croissant", url: "https://cdn.evidencepub.io/crosswalks/10.55458/neurolibre.00048/croissant.json" }] }
    end
    before { render partial: "papers/provenance_nl", locals: { paper: paper } }

    it "adds a last step after Published with the walk and the crosswalks" do
      expect(steps.map { |s| s.at_css("strong").text }.last(2)).to eq(["Published", "Explore and reuse"])
      last = steps.last
      expect(last.at_css(".nl-provenance__btn--sakiori")["href"]).to eq("https://sakiori.evidencepub.io/00048")
      links = last.css(".nl-provenance__artifact--crosswalk")
      expect(links.map { |l| l.text.squish }).to eq(["FAIR²", "Croissant"])
      expect(links.map { |l| l["href"] }).to eq(evidence[:crosswalks].map { |c| c[:url] })
    end
  end
end
