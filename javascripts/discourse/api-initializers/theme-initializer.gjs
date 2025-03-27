import { apiInitializer } from "discourse/lib/api";
import TopicTimerInfo from "discourse/components/topic-timer-info";

export default apiInitializer("topic-timer-to-top", (api) => {
  const showTop = settings.display_location === "top" || settings.display_location === "both";
  const showBottom = settings.display_location === "bottom" || settings.display_location === "both";

  if (showTop) {
    api.renderInOutlet("topic-above-posts", (outletArgs) => {
      const topic = outletArgs.model;
      const timer = topic?.topic_timer;
      if (!timer) return;

      let effectiveCategoryId = timer.category_id;

      if (settings.link_to_parent_category && timer.status_type === 4) {
        const store = api.container.lookup("service:store");
        const category = store.peekRecord("category", timer.category_id);
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

  if (!showBottom) {
    api.modifyClass("component:topic-timer-info", {
      didInsertElement() {
        if (!this.element.closest(".custom-topic-timer-top")) {
          this.element.remove();
        }
      },
    });
  }
});
