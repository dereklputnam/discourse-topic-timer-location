import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("topic-timer-to-top", (api) => {
  const displayLocation = settings.display_location;
  const renderTop = displayLocation === "Top" || displayLocation === "Both";
  const removeBottom = displayLocation === "Top";

  if (renderTop) {
    api.renderInOutlet("topic-above-posts", (outletArgs) => {
      const topic = outletArgs?.model;
      const categoryId = topic?.category_id;

      if (
        settings.enabled_category_ids?.length &&
        (!categoryId || !settings.enabled_category_ids.includes(categoryId))
      ) {
        return;
      }

      if (!topic?.topic_timer) return;

      return `
        <div class="custom-topic-timer-top">
          <topic-timer-info @model={{@model}} />
        </div>
      `;
    });
  }

  if (removeBottom) {
    api.modifyClass("component:topic-timer-info", {
      pluginId: "topic-timer-to-top",

      didInsertElement() {
        if (!this.element.closest(".custom-topic-timer-top")) {
          this.element.remove();
        }
      },
    });
  }

  if (settings.use_parent_for_link) {
    api.onPageChange(() => {
      requestAnimationFrame(() => {
        document.querySelectorAll(".topic-timer-info").forEach((el) => {
          const text = el.textContent?.trim();
          if (!text?.includes("will be published to")) return;

          const categoryLink = el.querySelector("a[href*='/c/']");
          if (!categoryLink) return;

          const href = categoryLink.getAttribute("href");
          const match = href.match(/\/c\/(.+)\/(\d+)/);
          if (!match) return;

          const slug = match[1].split("/").pop();
          const id = parseInt(match[2], 10);
          const cats = api.container.lookup("site:main").categories;
          const cat = cats.find((c) => c.id === id && c.slug === slug);
          if (!cat?.parent_category_id) return;

          const parent = cats.find((c) => c.id === cat.parent_category_id);
          if (!parent) return;

          categoryLink.textContent = `#${parent.slug}`;
        });
      });
    });
  }
});
