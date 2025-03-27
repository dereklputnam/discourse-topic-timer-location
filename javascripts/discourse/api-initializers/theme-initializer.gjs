import { apiInitializer } from "discourse/lib/api";
import I18n from "I18n";

export default apiInitializer("topic-timer-to-top", (api) => {
  const showTop = settings.display_location === "top" || settings.display_location === "both";
  const hideBottom = settings.display_location === "top";

  if (showTop) {
    api.renderInOutlet("topic-above-posts", <template>
      {{#if (and @outletArgs.model.topic_timer @outletArgs.model.topic_timer.execute_at)}}
        <div class="custom-topic-timer-top">
          {{html-safe (i18n "topic_timer.publish_to" category=@outletArgs.model.topic_timer.category_id time=@outletArgs.model.topic_timer.execute_at)}}
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

  if (settings.link_to_parent_category) {
    api.onPageChange(() => {
      requestAnimationFrame(() => {
        document.querySelectorAll(".custom-topic-timer-top a[href*='/c/']").forEach((link) => {
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
        });
      });
    });
  }
});
