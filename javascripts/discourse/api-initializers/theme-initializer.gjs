import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("topic-timer-to-top", (api) => {
  const displayLocation = settings.display_location;
  const showTop = displayLocation === "Top" || displayLocation === "Both";
  const hideBottom = displayLocation === "Top";

  if (showTop) {
    api.renderInOutlet("topic-above-posts", <template>
      {{#if
        (and
          @outletArgs.model.topic_timer
          (or
            (eq settings.enabled_category_ids.length 0)
            (includes settings.enabled_category_ids @outletArgs.model.category_id)
          )
        )
      }}
        <div class="custom-topic-timer-top">
          <topic-timer-info />
        </div>
      {{/if}}
    </template>);
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
