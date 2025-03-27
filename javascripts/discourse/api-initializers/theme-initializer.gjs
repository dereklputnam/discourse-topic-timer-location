import { apiInitializer } from "discourse/lib/api";
import TopicTimerInfo from "discourse/components/topic-timer-info";

export default apiInitializer("topic-timer-to-top", (api) => {
  const displayAtTop = settings.display_location === "Top" || settings.display_location === "Both";
  const displayAtBottom = settings.display_location === "Bottom" || settings.display_location === "Both";

  // Render top version if needed
  if (displayAtTop) {
    api.renderInOutlet("topic-above-posts", (outletArgs) => {
      const topic = outletArgs.model;
      const timer = topic?.topic_timer;
      if (!timer) return;

      let effectiveCategoryId = timer.category_id;

      if (settings.link_to_parent_category && timer.status_type === 4) {
        const category = api.container.lookup("store:main").peekRecord("category", timer.category_id);
        if (category?.parent_category_id) {
          effectiveCategoryId = category.parent_category_id;
        }
      }

      return (
        <div class="custom-topic-timer-top">
          <TopicTimerInfo
            @topicClosed={{@outletArgs.model.closed}}
            @statusType={{@outletArgs.model.topic_timer.status_type}}
            @statusUpdate={{@outletArgs.model.topic_status_update}}
            @executeAt={{@outletArgs.model.topic_timer.execute_at}}
            @basedOnLastPost={{@outletArgs.model.topic_timer.based_on_last_post}}
            @durationMinutes={{@outletArgs.model.topic_timer.duration_minutes}}
            @categoryId={effectiveCategoryId}
          />
        </div>
      );
    });
  }

  // Remove bottom version only if setting excludes it
  if (!displayAtBottom) {
    api.modifyClass("component:topic-timer-info", {
      didInsertElement() {
        if (!this.element.closest(".custom-topic-timer-top")) {
          this.element.remove();
        }
      },
    });
  }
});
