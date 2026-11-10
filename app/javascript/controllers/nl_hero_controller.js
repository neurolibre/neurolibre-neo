import { Controller } from "@hotwired/stimulus"

// NeuroLibre home page hero (home/_hero_nl).
//
// 1. Closes the gap the layout leaves above the page content (the header's
//    and the flash wrapper's margins), without covering a flash message.
// 2. On desktop widths, makes the hero exactly fill the window below the
//    navbar, scaling the layered stack, and the copy if needed, to fit.
//
// 3. Ties the layers together with red strings while "Start submission" is
//    hovered or focused (the .is-packed class).
//
// It only sets CSS variables and that class on the hero; hero_nl.scss decides what they do,
// and the hero keeps its fixed design size if this does not run.
const DESKTOP = 992        // px, the layout's lg breakpoint
const STACK_PAINT = 590    // px, how tall the layers actually paint at scale 1
const STACK_MAX = 1.2      // let the layers grow a little when there is room
const MIN_HEIGHT = 560     // px, never squeeze the hero below this

export default class extends Controller {
  static targets = ["copy"]

  connect() {
    this.fit = this.fit.bind(this)
    window.addEventListener("resize", this.fit)
    this.fit()
    if (document.fonts) document.fonts.ready.then(this.fit)

    // Pause the animations while the hero is scrolled out of view.
    if ("IntersectionObserver" in window) {
      this.observer = new IntersectionObserver(([entry]) => {
        this.element.classList.toggle("is-offscreen", !entry.isIntersecting)
      })
      this.observer.observe(this.element)
    }
  }

  disconnect() {
    window.removeEventListener("resize", this.fit)
    if (this.observer) this.observer.disconnect()
  }

  // Tie the layers together while "Start submission" is hovered or focused.
  pack() { this.element.classList.add("is-packed") }
  unpack() { this.element.classList.remove("is-packed") }

  fit() {
    const hero = this.element
    const style = hero.style
    for (const v of ["--nl-hero-pull", "--nl-hero-h", "--nl-hero-pad", "--nl-hero-stack", "--nl-hero-copy"]) style.removeProperty(v)

    // What the hero should sit right under: the header, or a flash message.
    const header = document.querySelector("header")
    const flash = document.getElementById("flash-message-wrapper")
    let anchor = header ? header.getBoundingClientRect().bottom : 0
    if (flash && flash.textContent.trim() !== "") anchor = flash.getBoundingClientRect().bottom + 8

    // The layout's margins collapse with the hero's own, so a margin equal to
    // the gap is not always enough. Measure again until the gap is closed.
    let pull = 0
    for (let i = 0; i < 6; i++) {
      const gap = hero.getBoundingClientRect().top - anchor
      if (gap <= 0.5) break
      pull -= gap
      style.setProperty("--nl-hero-pull", `${pull}px`)
    }

    if (window.innerWidth < DESKTOP) return

    const height = Math.max(MIN_HEIGHT, window.innerHeight - (anchor + window.scrollY))
    const pad = Math.round(Math.min(96, Math.max(32, height * 0.1)))
    const room = height - 2 * pad
    style.setProperty("--nl-hero-h", `${height}px`)
    style.setProperty("--nl-hero-pad", `${pad}px`)
    style.setProperty("--nl-hero-stack", Math.min(STACK_MAX, room / STACK_PAINT).toFixed(3))

    if (this.hasCopyTarget) {
      const copyHeight = this.copyTarget.offsetHeight
      if (copyHeight > room) style.setProperty("--nl-hero-copy", (room / copyHeight).toFixed(3))
    }
  }
}
