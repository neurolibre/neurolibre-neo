# NeuroLibre-only helpers for the home page hero (home/_hero_nl).
# Kept out of upstream helpers so upstream changes merge cleanly.
module NeurolibreHeroHelper
  # Layer colours, from the Evidence logo leaves (myst-theme-pretext leaf-shapes.ts).
  NL_HERO_COLORS = {
    data: "#37cae2", code: "#f97c0c", runtime: "#659b59", prose: "#6f00b7", accent: "#b256a1"
  }.freeze

  # The same seeded sequence the design used, so the page matches the mockup.
  class NlHeroSequence
    def initialize(seed)
      @seed = seed
    end

    def next
      @seed = (@seed * 9301 + 49_297) % 233_280
      @seed / 233_280.0
    end
  end

  def nl_hero_particles(count = 32)
    rnd = NlHeroSequence.new(13)
    palette = ["#CFF6FF", "#CFF6FF", "#CFF6FF", NL_HERO_COLORS[:data], NL_HERO_COLORS[:code],
               NL_HERO_COLORS[:runtime], NL_HERO_COLORS[:accent]]
    Array.new(count) do
      x = format("%.1f%%", 2 + rnd.next * 96)
      y = format("%.1f%%", 2 + rnd.next * 92)
      radius = 1.4 + rnd.next * 2.6
      size = format("%.1fpx", radius / 2)       # the bright core
      glow = format("%.1fpx", radius * 4)       # the box the glow fades out in
      offset = format("%.1fpx", -radius * 1.5)  # keep the dot centred where it was
      color = palette[(rnd.next * palette.length).floor]
      delays = [format("%.2fs", rnd.next * 3.8), format("%.2fs", rnd.next * 9)]
      { x: x, y: y, size: size, glow: glow, offset: offset, color: color, delays: delays }
    end
  end

  # Points for the illustrative scatter plot in the article layer.
  def nl_hero_scatter
    rnd = NlHeroSequence.new(13)
    (56 * 6).times { rnd.next } # same points as the design, independent of the particle count
    Array.new(10) do |j|
      x = 24 + j * 36
      y = 92 - (x / 380.0) * 78 + (rnd.next - 0.5) * 22
      { x: x.round, y: y.round, delay: format("%.2fs", j * 0.24) }
    end
  end

  # Illustrative rows for the data layer and the article's table.
  NL_HERO_DATA_ROWS = [
    %w[sub-01 ctrl 64 0.53], %w[sub-02 A 71 0.46], %w[sub-03 B 68 0.40],
    %w[sub-04 ctrl 59 0.55], %w[sub-05 B 73 0.39]
  ].freeze

  NL_HERO_TABLE_ROWS = [
    ["Corpus callosum", "48", "0.61", "-4.2%"], ["Fornix", "48", "0.44", "-7.9%"],
    ["Cingulum", "47", "0.52", "-2.1%"], ["Corticospinal", "48", "0.58", "+0.6%"]
  ].freeze
end
