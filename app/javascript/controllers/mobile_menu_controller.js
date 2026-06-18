import { Controller } from "@hotwired/stimulus"

// Toggles the mobile nav drawer. Targets: the collapsible menu panel.
export default class extends Controller {
  static targets = ["menu"]

  toggle() {
    this.menuTarget.classList.toggle("hidden")
  }

  close() {
    this.menuTarget.classList.add("hidden")
  }
}
