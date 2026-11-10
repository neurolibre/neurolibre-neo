import { Controller } from "@hotwired/stimulus"

// NeuroLibre submission form (papers/_form_nl).
// Shows the "DOI of the published version" field only for resubmissions.
// Stimulus runs connect() whenever Turbo renders the form, including after
// a failed submit, which a DOMContentLoaded listener does not.
export default class extends Controller {
  static targets = ["kind", "parentDoi"]

  connect() {
    this.toggleParentDoi()
  }

  toggleParentDoi() {
    if (!this.hasKindTarget || !this.hasParentDoiTarget) return
    this.parentDoiTarget.hidden = this.kindTarget.value !== "resubmission"
  }
}
