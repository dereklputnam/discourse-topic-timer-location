import { apiInitializer } from "discourse/lib/api";
import TopicTimerInfo from "discourse/components/topic-timer-info";

export default apiInitializer("topic-timer-to-top", (api) => {
  const displayLocation = settings.display_location;
  const showTop = displayLocation === "top" || displayLocation === "both";
  const removeBottom = displayLocation === "top";

  // ✅ Render timer at the top using outletArgs directly
  if (showTop) {
    api.renderInOutlet("topic-above-posts", (outletArgs) => {
      const topic = outletArgs?.model;
      const timer = topic?.topic_timer;
      if (!timer) return;

      return (
        <TopicTimerInfo
          @topicClosed={topic.closed}
          @statusType={timer.status_type}
          @statusUpdate={topic.topic_status_update}
          @executeAt={timer.execute_at}
          @basedOnLastPost={timer.based_on_last_post}
          @durationMinutes={timer.duration_minutes}
          @categoryId={timer.category_id}
        />
      );
    });
  }

  // ✅ Remove bottom version if top-only
  if (removeBottom) {
    api.modifyClass("component:topic-timer-info", {
      didInsertElement() {
        if (!this.element.closest("[data-plugin-outlet='topic-above-posts']")) {
          this.element.remove();
        }
      },
    });
  }

  // ✅ DOM patch: label and parent category
  if (settings.link_to_parent_category || settings.topic_label_override) {
    api.onPageChange(() => {
      requestAnimationFrame(() => {
        const allTimers = document.querySelectorAll(".topic-timer-info");

        allTimers.forEach((el) => {
          const text = el.textContent?.trim();
          if (!text?.includes("will be published to")) return;

          // 🔤 Replace "This topic" label
          if (settings.topic_label_override) {
            el.innerHTML = el.innerHTML.replace(
              /\bThis topic\b/i,
              `This ${settings.topic_label_override}`
            );
          }

          // 🔁 Swap category link to parent
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
