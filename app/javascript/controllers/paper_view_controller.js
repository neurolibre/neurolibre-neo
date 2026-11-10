import { Controller } from "@hotwired/stimulus"

// NeuroLibre paper page (papers/_paper_view_nl): switch between the living
// preprint and the PDF. The PDF is created from its <template> the first
// time it is shown, so readers who stay on the living version never download
// it. "#pdf" in the address opens the PDF, and switching keeps it in sync.
export default class extends Controller {
  static targets = ["tab", "living", "pdf", "pdfTemplate"]

  connect() {
    if (!this.hasLivingTarget) return
    this.select(window.location.hash === "#pdf" ? "pdf" : "living", false)
  }

  show(event) {
    this.select(event.currentTarget.dataset.view, true)
  }

  select(view, updateAddress) {
    if (view === "pdf" && this.hasPdfTemplateTarget && !this.pdfTarget.hasChildNodes()) {
      this.pdfTarget.appendChild(this.pdfTemplateTarget.content.cloneNode(true))
    }
    this.livingTarget.hidden = view !== "living"
    this.pdfTarget.hidden = view !== "pdf"
    this.tabTargets.forEach((tab) => tab.setAttribute("aria-pressed", String(tab.dataset.view === view)))

    if (updateAddress) {
      const url = new URL(window.location.href)
      url.hash = view === "pdf" ? "pdf" : ""
      history.replaceState(history.state, "", url)
    }
  }
}
