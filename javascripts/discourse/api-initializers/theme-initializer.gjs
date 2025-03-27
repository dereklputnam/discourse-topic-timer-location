import { apiInitializer } from "discourse/lib/api";
import TopicTimerInfo from "discourse/components/topic-timer-info";

export default apiInitializer("topic-timer-to-top", (api) => {
  const showTop = settings.display_location === "top" || settings.display_location === "both";
  const showBottom = settings.display_location === "bottom" || settings.display_location === "both";

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

  // Hide the bottom one if needed
  if (!showBottom) {
    api.modifyClass("component:topic-timer-info", {
      didInsertElement() {
        if (!this.element.closest(".custom-topic-timer-top")) {
          this.element.remove();
        }
      },
    });
  }

  // Override the category link if enabled
  if (settings.link_to_parent_category) {
    api.modifyClass("component:topic-timer-info", {
      pluginId: "topic-timer-to-top",

      get computedCategory() {
        const categoryId = this.args.categoryId;
        if (!categoryId) return null;

        const category = this.site.categories.find((c) => c.id === categoryId);
        if (category?.parent_category_id) {
          return this.site.categories.find((c) => c.id === category.parent_category_id) || category;
        }

        return category;
      },

      get message() {
        let key;
        switch (this.args.statusType) {
          case 1:
            key = "topic_timer.close_scheduled";
            break;
          case 2:
            key = "topic_timer.open_scheduled";
            break;
          case 3:
            key = "topic_timer.delete_scheduled";
            break;
          case 4:
            key = "topic_timer.publish_scheduled";
            break;
          default:
            return;
        }

        return this.intl.t(key, {
          duration_minutes: this.args.durationMinutes,
          execute_at: this.args.executeAt,
          based_on_last_post: this.args.basedOnLastPost,
          category: this.computedCategory,
        });
      },
    });
  }
});
