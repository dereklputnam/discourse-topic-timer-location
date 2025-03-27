import { apiInitializer } from "discourse/lib/api";
import TopicTimerInfo from "discourse/components/topic-timer-info";

export default apiInitializer("topic-timer-to-top", (api) => {
  const displayLocation = settings.display_location;
  const renderTopTimer = displayLocation === "top" || displayLocation === "both";
  const removeBottomTimer = displayLocation === "top";

  // ✅ Render top timer
  if (renderTopTimer) {
    api.renderInOutlet("topic-above-posts", <template>
      {{#if @outletArgs.model.topic_timer}}
        <TopicTimerInfo
          @topicClosed={{@outletArgs.model.closed}}
          @statusType={{@outletArgs.model.topic_timer.status_type}}
          @statusUpdate={{@outletArgs.model.topic_status_update}}
          @executeAt={{@outletArgs.model.topic_timer.execute_at}}
          @basedOnLastPost={{@outletArgs.model.topic_timer.based_on_last_post}}
          @durationMinutes={{@outletArgs.model.topic_timer.duration_minutes}}
          @categoryId={{@outletArgs.model.topic_timer.category_id}}
        />
      {{/if}}
    </template>);
  }

  // ✅ Hide default (bottom) version if needed
  if (removeBottomTimer) {
    api.modifyClass("component:topic-timer-info", {
      didInsertElement() {
        if (!this.element.closest(".topic-above-posts")) {
          this.element.remove();
        }
      },
    });
  }

  // ✅ Replace category link with parent category (DOM patch)
  if (settings.link_to_parent_category || settings.topic_label_override) {
    api.onPageChange(() => {
      requestAnimationFrame(() => {
        const allTimers = document.querySelectorAll(".topic-timer-info");

        allTimers.forEach((el) => {
          let text = el.textContent?.trim();
          if (!text?.includes("will be published to")) return;

          // ✅ Swap "topic" with custom label if needed
          if (settings.topic_label_override) {
            el.innerHTML = el.innerHTML.replace(
              /\bThis topic\b/,
              `This ${settings.topic_label_override}`
            );
          }

          // ✅ Replace with parent category if enabled
          if (settings.link_to_parent_category) {
            const categoryLink = el.querySelector("a[href*='/c/']");
            if (!categoryLink) return;

            const href = categoryLink.getAttribute("href");
            const match = href.match(/\/c\/(.+)\/(\d+)/);
            if (!match) return;

            const fullSlug = match[1];
            const slug = fullSlug.split("/").pop();
            const id = parseInt(match[2], 10);
            const siteCategories = api.container.lookup("site:main").categories;

            const category = siteCategories.find((cat) => cat.id === id && cat.slug === slug);
            if (!category?.parent_category_id) return;

            const parent = siteCategories.find((cat) => cat.id === category.parent_category_id);
            if (!parent) return;

            categoryLink.textContent = `#${parent.slug}`;
            categoryLink.setAttribute("href", `/c/${parent.slug}/${parent.id}`);
          }
        });
      });
    });
  }
});
