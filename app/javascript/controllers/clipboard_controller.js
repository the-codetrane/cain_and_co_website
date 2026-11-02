import { Controller } from "@hotwired/stimulus"

// Copies the source element's text to the clipboard and briefly confirms on the button.
//
//   <div data-controller="clipboard">
//     <p data-clipboard-target="source">…</p>
//     <button data-clipboard-target="button" data-action="clipboard#copy">Copy</button>
//   </div>
export default class extends Controller {
  static targets = ["source", "button"]

  async copy() {
    const text = this.sourceTarget.innerText.trim()
    try {
      await navigator.clipboard.writeText(text)
      this.#flash("Copied")
    } catch {
      this.#flash("Select & copy")
    }
  }

  #flash(label) {
    if (!this.hasButtonTarget) return
    const original = this.buttonTarget.dataset.label ||= this.buttonTarget.textContent
    this.buttonTarget.textContent = label
    clearTimeout(this.timer)
    this.timer = setTimeout(() => { this.buttonTarget.textContent = original }, 2000)
  }
}
