import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["venmoTab", "cashappTab", "venmoContent", "cashappContent"]

  connect() {
    this.activate("venmo")
  }

  showVenmo() { this.activate("venmo") }
  showCashapp() { this.activate("cashapp") }

  activate(app) {
    const isVenmo = app === "venmo"

    this.venmoTabTarget.classList.toggle("bg-white", isVenmo)
    this.venmoTabTarget.classList.toggle("text-neutral-900", isVenmo)
    this.venmoTabTarget.classList.toggle("text-neutral-400", !isVenmo)

    this.cashappTabTarget.classList.toggle("bg-white", !isVenmo)
    this.cashappTabTarget.classList.toggle("text-neutral-900", !isVenmo)
    this.cashappTabTarget.classList.toggle("text-neutral-400", isVenmo)

    this.venmoContentTarget.classList.toggle("hidden", !isVenmo)
    this.cashappContentTarget.classList.toggle("hidden", isVenmo)
  }
}
