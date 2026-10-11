import { Mosaic } from "./mosaic";
import { Exhibit } from "./exhibit";

const syncPageMetadata = (element) => {
  const { pageTitle, description, image, url } = element.dataset;
  const metadata = [
    ['meta[name="description"]', description],
    ['meta[property="og:title"]', pageTitle],
    ['meta[property="og:description"]', description],
    ['meta[property="og:url"]', url],
    ['meta[property="og:image"]', image],
    ['meta[name="twitter:title"]', pageTitle],
    ['meta[name="twitter:description"]', description],
    ['meta[name="twitter:image"]', image],
    ['meta[itemprop="image"]', image]
  ];

  metadata.forEach(([selector, content]) => {
    document.head.querySelector(selector)?.setAttribute("content", content || "");
  });
};

export const PublicPage = {
  mounted() {
    this.pagePath = this.el.dataset.path;
    syncPageMetadata(this.el);
  },

  updated() {
    syncPageMetadata(this.el);
    const pagePath = this.el.dataset.path;
    if (pagePath === this.pagePath) return;

    this.pagePath = pagePath;
    document.querySelectorAll("header details[open]").forEach((menu) => {
      menu.open = false;
    });
    window.scrollTo(0, 0);
  }
};

const ExhibitRoomEditor = {
  mounted() {
    // LiveView preserves focused input values, even when the editor revision changes.
    if (this.el.dataset.editing === "false" && this.el.contains(document.activeElement)) {
      document.activeElement.blur();
    }
    this.el.querySelector("form").reset();
    for (const field of ["name", "type", "position"]) {
      this.el.querySelector(`[name="room[${field}]"]`).value = this.el.dataset[field] ?? "";
    }
  }
};

export default { PublicPage, Mosaic, Exhibit, ExhibitRoomEditor };
