import { apiInitializer } from "discourse/lib/api";
import TopicTimerInfo from "discourse/components/topic-timer-info";

export default apiInitializer("topic-timer-to-top", (api) => {
  const displayLocation = settings.display_location;
  const showTop = displayLocation === "Top" || displayLocation === "Both";
  const hideBottom = displayLocation === "Top";

  if (showTop) {
    // ✅ Register the outlet, and use a gate function
    api.includePostAttributes("category_id");

    api.renderInOutlet("topic-above-posts", (outletArgs) => {
      const topic = outletArgs?.model;
      const categoryId = topic?.category_id;

      // ✅ JS filter for enabled categories
      if (
        settings.enabled_category_ids?.length &&
        (!categoryId || !settings.enabled_category_ids.includes(categoryId))
      ) {
        return null;
      }

      // ✅ Template version (no logic inside)
      return {
        template: "topic-timer-top",
        outletArgs,
      };
    });
  }

  if (hideBottom) {
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
