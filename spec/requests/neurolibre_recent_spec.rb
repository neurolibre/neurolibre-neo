require "rails_helper"

describe "Loading more papers on the home page", type: :request do
  before do
    allow_any_instance_of(NeurolibreHelper).to receive(:prefetch_card_images)
    allow_any_instance_of(NeurolibreHelper).to receive(:pretty_card_image).and_return("https://example.org/featured.png")
    Searchkick.callbacks(false) do
      21.times do |i|
        create(:accepted_paper, title: "Paper #{i}", doi: format("10.55458/neurolibre.%05d", i), accepted_at: (i + 1).days.ago)
      end
    end
  end

  it "returns the next nine papers after the home page's ten, in a frame with a link to the page after" do
    get "/recent", params: { page: 2 }
    doc = Nokogiri::HTML(response.body)
    frame = doc.at_css("turbo-frame#nl-recent-page-2")
    expect(frame).to be_present
    expect(frame.css(".nl-recent__card h3").map { |h| h.text.squish }).to eq((10..18).map { |i| "Paper #{i}" })
    expect(frame.at_css("turbo-frame#nl-recent-page-3 a.nl-recent__more")["href"]).to eq("/recent?page=3")
  end

  it "stops offering more when the last papers are shown" do
    get "/recent", params: { page: 3 }
    doc = Nokogiri::HTML(response.body)
    expect(doc.css("turbo-frame#nl-recent-page-3 .nl-recent__card").size).to eq(2)
    expect(doc.at_css("a.nl-recent__more")).to be_nil
  end
end
