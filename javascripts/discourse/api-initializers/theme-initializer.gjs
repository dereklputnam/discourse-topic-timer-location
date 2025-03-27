import { apiInitializer } from "discourse/lib/api";
import TopicTimerInfo from "discourse/components/topic-timer-info";

export default apiInitializer("topic-timer-to-top", (api) => {
  const displayAtTop = settings.display_location === "top" || settings.display_location === "both";
  const hideBottom = settings.display_location === "top";

  if (displayAtTop) {
    api.renderInOutlet("topic-above-posts", (outletArgs) => {
      const topic = outletArgs.model;
      const timer = topic?.topic_timer;
      if (!timer) return;

      let effectiveCategoryId = timer.category_id;

      // For publish timers (status_type === 4), override with parent category if enabled
      if (settings.link_to_parent_category && timer.status_type === 4) {
        const category = api.container.lookup("store:main").peekRecord("category", timer.category_id);
        if (category?.parent_category_id) {
          effectiveCategoryId = category.parent_category_id;
        }
      }

      return (
        <div class="custom-topic-timer-top">
          <TopicTimerInfo
            @topicClosed={topic.closed}
            @statusType={timer.status_type}
            @statusUpdate={topic.topic_status_update}
            @executeAt={timer.execute_at}
            @basedOnLastPost={timer.based_on_last_post}
            @durationMinutes={timer.duration_minutes}
            @categoryId={effectiveCategoryId}
          />
        </div>
      );
    });
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
});
