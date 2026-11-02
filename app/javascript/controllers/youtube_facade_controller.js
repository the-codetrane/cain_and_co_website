import { Controller } from "@hotwired/stimulus"

// Lightweight YouTube "facade": render only a thumbnail + play button, and swap in
// the real (heavy) iframe when the visitor clicks. Keeps /epk fast on phones while
// still playing inline, so no one is sent away to YouTube.
//
//   <div data-controller="youtube-facade" data-youtube-facade-src-value="https://www.youtube-nocookie.com/embed/ID">
//     <button data-action="youtube-facade#play">…thumbnail…</button>
//   </div>
export default class extends Controller {
  static values = { src: String, title: String }

  play() {
    const iframe = document.createElement("iframe")
    iframe.src = `${this.srcValue}?autoplay=1&rel=0`
    iframe.title = this.titleValue
    iframe.className = "w-full h-full"
    iframe.allow = "accelerometer; autoplay; clipboard-write; encrypted-media; gyroscope; picture-in-picture; web-share"
    iframe.allowFullscreen = true
    this.element.replaceChildren(iframe)
  }
}
