require "rails_helper"

describe "papers/_paper_view_nl.html.erb", type: :view do
  let(:doc) { Nokogiri::HTML(rendered) }

  context "when the paper has a living preprint" do
    let(:paper) { build(:accepted_paper, doi: "10.55458/neurolibre.00048", book_exec_url: "https://preprint.neurolibre.org/10.55458/neurolibre.00048") }
    before { render partial: "papers/paper_view_nl", locals: { paper: paper } }

    it "shows the living preprint by default, with a toggle to the PDF" do
      buttons = doc.css(".nl-paper-view__toggle button")
      expect(buttons.map { |b| b.text.squish }).to eq(["Living preprint", "PDF"])
      expect(buttons.map { |b| b["aria-pressed"] }).to eq(%w[true false])
      frame = doc.at_css(".nl-paper-view__living iframe")
      expect(frame["src"]).to eq(paper.book_exec_url)
      expect(frame["title"]).to be_present
      expect(doc.at_css(".nl-paper-view__pdf")["hidden"]).not_to be_nil
    end

    it "keeps the PDF out of the page until it is asked for" do
      expect(doc.at_css(".nl-paper-view__pdf object")).to be_nil
      template = doc.at_css("template[data-paper-view-target=pdfTemplate]")
      expect(template.inner_html).to include(paper.pdf_url)
    end

    it "offers the living preprint in a new tab" do
      link = doc.at_css(".nl-paper-view__open")
      expect(link["href"]).to eq(paper.book_exec_url)
      expect(link["target"]).to eq("_blank")
    end
  end

  context "when the paper has no living preprint" do
    let(:paper) { build(:accepted_paper, doi: "10.55458/neurolibre.00010", book_exec_url: nil) }
    before { render partial: "papers/paper_view_nl", locals: { paper: paper } }

    it "shows the PDF straight away, without a toggle" do
      expect(doc.at_css(".nl-paper-view__toggle")).to be_nil
      expect(doc.at_css(".nl-paper-view__pdf object#joss-paper")["data"]).to include(paper.pdf_url)
    end
  end
end
