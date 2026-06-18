import { Controller } from "@hotwired/stimulus"

// Toggles the mobile nav drawer. Targets: the collapsible menu panel and the toggle button.
export default class extends Controller {
  static targets = ["menu", "button"]

  toggle() {
    const expanded = this.buttonTarget.getAttribute("aria-expanded") === "true"
    this.buttonTarget.setAttribute("aria-expanded", String(!expanded))
    this.menuTarget.classList.toggle("hidden")
  }

  close() {
    this.buttonTarget.setAttribute("aria-expanded", "false")
    this.menuTarget.classList.add("hidden")
  }
}
