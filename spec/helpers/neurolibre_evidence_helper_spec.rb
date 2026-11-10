require "rails_helper"

describe NeurolibreEvidenceHelper, type: :helper do
  let(:paper) { build(:accepted_paper, doi: "10.55458/neurolibre.00048") }
  let(:index) do
    { "10.55458/neurolibre.00048" => { "crosswalks" => {
        "fair2" => "crosswalks/10.55458/neurolibre.00048/fair2.json",
        "croissant" => "crosswalks/10.55458/neurolibre.00048/croissant.json" } },
      "10.55458/neurolibre.00010" => {} }
  end

  before { NeurolibreEvidenceHelper.clear_evidence_index_cache! }
  after { NeurolibreEvidenceHelper.clear_evidence_index_cache! }

  it "gives the Sakiori walk and the crosswalks of a paper in the index" do
    allow(helper).to receive(:nl_evidence_index).and_return(index)
    expect(helper.nl_evidence(paper)).to eq(
      sakiori: "https://sakiori.evidencepub.io/00048",
      crosswalks: [{ label: "FAIR²", url: "https://cdn.evidencepub.io/crosswalks/10.55458/neurolibre.00048/fair2.json" },
                   { label: "Croissant", url: "https://cdn.evidencepub.io/crosswalks/10.55458/neurolibre.00048/croissant.json" }])
  end

  it "gives the walk without crosswalks when the paper has none" do
    allow(helper).to receive(:nl_evidence_index).and_return(index)
    other = build(:accepted_paper, doi: "10.55458/neurolibre.00010")
    expect(helper.nl_evidence(other)).to eq(sakiori: "https://sakiori.evidencepub.io/00010", crosswalks: [])
  end

  it "gives nothing for a paper the index does not list" do
    allow(helper).to receive(:nl_evidence_index).and_return(index)
    expect(helper.nl_evidence(build(:accepted_paper, doi: "10.55458/neurolibre.00099"))).to be_nil
  end

  it "reads the index once and remembers it" do
    expect(helper).to receive(:nl_fetch_cdn).with("index.json").once.and_return({ papers: index }.to_json)
    2.times { helper.nl_evidence(paper) }
  end

  it "points at the article's MyST JSON, named by the project's index page" do
    config = { projects: [{ doi: "10.55458/neurolibre.00048", slug: "neurolibre-00048", index: "paper" }] }
    allow(helper).to receive(:nl_fetch_cdn).with("config.json").and_return(config.to_json)
    expect(helper.nl_structured_content_url(paper)).to eq("https://cdn.evidencepub.io/content/neurolibre-00048/paper.json")
    expect(helper.nl_structured_content_url(build(:accepted_paper, doi: "10.55458/neurolibre.00099"))).to be_nil
  end

  it "gives nothing when the CDN cannot be reached" do
    allow(Net::HTTP).to receive(:start).and_raise(Errno::ECONNREFUSED)
    expect(helper.nl_evidence(paper)).to be_nil
    expect(helper.nl_structured_content_url(paper)).to be_nil
  end
end
