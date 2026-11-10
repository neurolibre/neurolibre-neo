import { Controller } from "@hotwired/stimulus"

// NeuroLibre submission form (papers/_form_nl).
// Shows the "DOI of the published version" field only for resubmissions,
// and the data DOI field (required) only when the author answers Yes.
// Stimulus runs connect() whenever Turbo renders the form, including after
// a failed submit, which a DOMContentLoaded listener does not.
export default class extends Controller {
  static targets = ["kind", "parentDoi", "dataDoiAnswer", "dataDoi", "dataDoiInput"]

  connect() {
    this.toggleParentDoi()
    this.toggleDataDoi()
  }

  toggleDataDoi() {
    if (!this.hasDataDoiTarget || !this.hasDataDoiInputTarget) return
    const yes = this.dataDoiAnswerTargets.some((radio) => radio.checked && radio.value === "yes")
    this.dataDoiTarget.hidden = !yes
    this.dataDoiInputTarget.required = yes
  }

  toggleParentDoi() {
    if (!this.hasKindTarget || !this.hasParentDoiTarget) return
    this.parentDoiTarget.hidden = this.kindTarget.value !== "resubmission"
  }
}
