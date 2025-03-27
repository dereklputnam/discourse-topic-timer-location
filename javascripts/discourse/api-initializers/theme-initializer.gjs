import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("topic-timer-to-top", (api) => {
  const showTop = settings.display_location === "top" || settings.display_location === "both";
  const hideBottom = settings.display_location === "top";

  if (showTop) {
    api.renderInOutlet("topic-above-posts", <template>
      {{#if @outletArgs.model.topic_timer}}
        <div class="custom-topic-timer-top">
          <topic-timer-info />
        </div>
      {{/if}}
    </template>);
  }

  if (hideBottom) {
    api.modifyClass("component:topic-timer-info", {
      didInsertElement() {
        if (!this.element.closest(".custom-topic-timer-top")) {
          this.element.remove();
        }
      },
    });
  }

  if (settings.link_to_parent_category || settings.topic_label_override) {
    api.onPageChange(() => {
      requestAnimationFrame(() => {
        document.querySelectorAll(".topic-timer-info").forEach((el) => {
          const text = el.textContent?.trim();
          if (!text?.includes("will be published to")) return;

          if (settings.topic_label_override) {
            el.innerHTML = el.innerHTML.replace(
              /\bThis topic\b/i,
              `This ${settings.topic_label_override}`
            );
          }

          if (settings.link_to_parent_category) {
            const link = el.querySelector("a[href*='/c/']");
            if (!link) return;

            const href = link.getAttribute("href");
            const match = href.match(/\/c\/(.+)\/(\d+)/);
            if (!match) return;

            const slug = match[1].split("/").pop();
            const id = parseInt(match[2], 10);
            const cats = api.container.lookup("site:main").categories;
            const cat = cats.find((c) => c.id === id && c.slug === slug);
            if (!cat?.parent_category_id) return;

            const parent = cats.find((c) => c.id === cat.parent_category_id);
            if (!parent) return;

            link.textContent = `#${parent.slug}`;
            link.setAttribute("href", `/c/${parent.slug}/${parent.id}`);
          }
        });
      });
    });
  }
});
