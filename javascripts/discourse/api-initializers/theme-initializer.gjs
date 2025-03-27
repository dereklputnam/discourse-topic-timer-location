import { apiInitializer } from "discourse/lib/api";
import TopicTimerInfo from "discourse/components/topic-timer-info";

export default apiInitializer("topic-timer-to-top", (api) => {
  const showTop = settings.display_location === "top" || settings.display_location === "both";
  const showBottom = settings.display_location === "bottom" || settings.display_location === "both";

  // Renders the timer at the top of the topic if enabled
  if (showTop) {
    api.renderInOutlet("topic-above-posts", <template>
      {{#if @outletArgs.model.topic_timer}}
        <div class="custom-topic-timer-top">
          <TopicTimerInfo
            @topicClosed={{@outletArgs.model.closed}}
            @statusType={{@outletArgs.model.topic_timer.status_type}}
            @statusUpdate={{@outletArgs.model.topic_status_update}}
            @executeAt={{@outletArgs.model.topic_timer.execute_at}}
            @basedOnLastPost={{@outletArgs.model.topic_timer.based_on_last_post}}
            @durationMinutes={{@outletArgs.model.topic_timer.duration_minutes}}
            @categoryId={{@outletArgs.model.topic_timer.category_id}}
          />
        </div>
      {{/if}}
    </template>);
  }

  // Hides the bottom version if needed
  if (!showBottom) {
    api.modifyClass("component:topic-timer-info", {
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
      const allTimers = document.querySelectorAll(".topic-timer-info");
      console.log(`[topic-timer-to-top] Found ${allTimers.length} .topic-timer-info elements`);

      allTimers.forEach((el, i) => {
        const text = el.textContent?.trim();
        console.log(`[${i}] Text content:`, text);

        if (!text?.includes("will be published to")) {
          console.log(`[${i}] Skipping: not a publish timer`);
          return;
        }

        const categoryLink = el.querySelector("a[href*='/c/']");
        if (!categoryLink) {
          console.log(`[${i}] Skipping: no category link found`);
          return;
        }

        const href = categoryLink.getAttribute("href");
        const match = href.match(/\/c\/([^\/]+)\/(\d+)/);
        if (!match) {
          console.log(`[${i}] Skipping: href did not match expected format`, href);
          return;
        }

        const slug = match[1];
        const id = parseInt(match[2], 10);
        const siteCategories = api.container.lookup("site:main").categories;

        const category = siteCategories.find((cat) => cat.id === id && cat.slug === slug);
        if (!category) {
          console.log(`[${i}] Skipping: no matching category found`);
          return;
        }

        if (!category.parent_category_id) {
          console.log(`[${i}] Skipping: no parent category for`, category.slug);
          return;
        }

        const parent = siteCategories.find((cat) => cat.id === category.parent_category_id);
        if (!parent) {
          console.log(`[${i}] Skipping: parent category not found`);
          return;
        }

        console.log(`[${i}] ✅ Replacing category link: ${category.slug} → ${parent.slug}`);

        categoryLink.textContent = `#${parent.slug}`;
        categoryLink.setAttribute("href", `/c/${parent.slug}/${parent.id}`);
      });
    });
  });
}
});
