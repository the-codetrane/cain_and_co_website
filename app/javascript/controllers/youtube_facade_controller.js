import { Controller } from "@hotwired/stimulus"

// Lightweight YouTube "facade": render only a thumbnail + play button, and swap in
// the real (heavy) iframe when the visitor clicks. Keeps /epk fast on phones while
// still playing inline, so no one is sent away to YouTube.
//
// The poster starts at maxresdefault (1280×720). YouTube serves a 120×90 grey
// placeholder (HTTP 200, not an error) when a video has no maxres image, so
// fall back to hqdefault on a tiny image as well as on a load error.
//
//   <div data-controller="youtube-facade" data-youtube-facade-src-value="https://www.youtube-nocookie.com/embed/ID">
//     <button data-action="youtube-facade#play">
//       <img data-youtube-facade-target="poster" data-fallback-src="…/hqdefault.jpg">
//     </button>
//   </div>
export default class extends Controller {
  static targets = ["poster"]
  static values = { src: String, title: String }

  posterTargetConnected(img) {
    const check = () => {
      if (img.naturalWidth <= 120 && img.dataset.fallbackSrc && img.src !== img.dataset.fallbackSrc) {
        img.src = img.dataset.fallbackSrc
      }
    }
    img.addEventListener("error", () => { if (img.dataset.fallbackSrc) img.src = img.dataset.fallbackSrc }, { once: true })
    if (img.complete) check()
    else img.addEventListener("load", check, { once: true })
  }

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
