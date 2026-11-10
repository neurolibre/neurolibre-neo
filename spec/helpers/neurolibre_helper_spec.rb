require "rails_helper"

describe NeurolibreHelper, type: :helper do
  let(:paper) { build(:paper, repository_url: "https://github.com/neurolibre/example-paper") }
  let(:base) { "https://raw.githubusercontent.com/neurolibre/example-paper" }

  before { NeurolibreHelper.clear_card_image_cache! }

  it "prefers main over master and png over the other formats" do
    found = ["#{base}/master/featured.png", "#{base}/main/featured.jpg"]
    allow(helper).to receive(:url_exist?) { |url| found.include?(url) }
    expect(helper.pretty_card_image(paper)).to eq("#{base}/master/featured.png")
  end

  it "falls back to the NeuroLibre pattern when the repository has no featured image" do
    allow(helper).to receive(:url_exist?).and_return(false)
    expect(helper.pretty_card_image(paper)).to eq("https://raw.githubusercontent.com/neurolibre/brand/main/png/pattern_dark.png")
  end

  it "looks each repository up once and then answers from the cache" do
    calls = 0
    allow(helper).to receive(:url_exist?) { |url| calls += 1; url == "#{base}/main/featured.webp" }
    first = helper.pretty_card_image(paper)
    calls_after_first = calls
    second = helper.pretty_card_image(paper)
    expect(second).to eq(first)
    expect(calls_after_first).to eq(10)
    expect(calls).to eq(calls_after_first)
  end

  it "looks up a whole list of cards at once" do
    papers = %w[one two three].map { |r| build(:paper, repository_url: "https://github.com/neurolibre/#{r}") }
    allow(helper).to receive(:url_exist?) { |url| sleep 0.2; url.end_with?("/main/featured.png") }
    started = Time.now
    helper.prefetch_card_images(papers)
    expect(Time.now - started).to be < 1.0 # 3 papers x 10 checks x 0.2s would be 6s one after another
    expect(helper.pretty_card_image(papers.last)).to eq("https://raw.githubusercontent.com/neurolibre/three/main/featured.png")
  end

  it "treats a network error or a timeout as no image" do
    allow(Net::HTTP).to receive(:new).and_raise(Net::OpenTimeout)
    expect(helper.url_exist?("#{base}/main/featured.png")).to be(false)
  end
end
