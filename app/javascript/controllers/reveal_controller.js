import { Controller } from "@hotwired/stimulus"

// Shows items that start hidden, then removes the button. Used to collapse long
// lists (e.g. the /epk show history) to the most recent rows.
//
//   <div data-controller="reveal">
//     <tbody data-reveal-target="item" hidden>…</tbody>
//     <button data-reveal-target="button" data-action="reveal#show">Show all</button>
//   </div>
export default class extends Controller {
  static targets = ["item", "button"]

  show() {
    this.itemTargets.forEach((el) => { el.hidden = false })
    this.buttonTargets.forEach((el) => el.remove())
  }
}
