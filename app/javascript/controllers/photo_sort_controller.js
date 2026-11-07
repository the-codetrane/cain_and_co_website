import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static values = { url: String }

  connect() {
    this.sortable = Sortable.create(this.element, {
      animation: 150,
      // On touch a drag needs a press first, so a swipe across the grid still scrolls.
      delay: 200,
      delayOnTouchOnly: true,
      // In pointer mode the cancel from that scroll goes unnoticed and leaves Sortable
      // mid-drag, so it ignores the next press. Touch events always reach its cleanup.
      supportPointer: false,
      ghostClass: "opacity-30",
      chosenClass: "opacity-75",
      dragClass: "shadow-xl",
      onEnd: () => this.persist()
    })
  }

  disconnect() {
    this.sortable.destroy()
  }

  persist() {
    const ids = Array.from(this.element.children).map(el => el.dataset.photoId)
    fetch(this.urlValue, {
      method: "PATCH",
      headers: {
        "Content-Type": "application/json",
        "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]').content
      },
      body: JSON.stringify({ ids })
    })
  }
}
