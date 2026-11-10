# NeuroLibre-only helpers for the submission form (papers/_form_nl).
# Kept out of PapersHelper so upstream changes to that file merge cleanly.
module NeurolibreFormHelper
  # Red asterisk after the label of a required form field.
  def required_mark
    content_tag(:span, "*", class: "required-mark", title: "Required")
  end
end
