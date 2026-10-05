import { apiInitializer } from "discourse/lib/api";
import TopicTimerInfo from "discourse/components/topic-timer-info";
import or from "truth-helpers/helpers/or";
import icon from "discourse-common/helpers/d-icon";
import Category from "discourse/models/category";

export default apiInitializer("topic-timer-to-top", (api) => {
  const displayLocation = settings.display_location;
  const renderTopTimer = displayLocation === "Top" || displayLocation === "Both";
  const removeBottomTimer = displayLocation === "Top";
  
  // Parse enabled categories
  const enabledCategories = settings.enabled_categories
    .split("|")
    .map((id) => parseInt(id, 10))
    .filter((id) => id);
    
  // Helper function to check if a category is enabled
  const isCategoryEnabled = (categoryId) => {
    // If no categories are specified, apply to all
    if (enabledCategories.length === 0) {
      return true;
    }
    
    return enabledCategories.includes(categoryId);
  };

  api.modifyClass("component:topic-timer-info", (Superclass) =>
    class extends Superclass {
      additionalOpts() {
        const category = this.categoryId && Category.findById(this.categoryId);
        return category ? { categoryName: category.name } : {};
      }
    }
  );

  const reminderText = settings.reminder_text;

  if (renderTopTimer) {
    api.renderInOutlet("topic-above-posts", <template>
      {{#if (isCategoryEnabled @outletArgs.model.category.id)}}
        {{#if (or reminderText @outletArgs.model.topic_timer)}}
          <div class="custom-topic-timer-top">
            {{#if reminderText}}
              <h2 class="custom-topic-timer-top__reminder">{{icon "comment-slash"}}{{reminderText}}</h2>
            {{/if}}
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
          </div>
        {{/if}}
      {{/if}}
    </template>);
  }

  // Additional cleanup for bottom timer when in "Top" mode
  if (removeBottomTimer) {
    api.modifyClass("component:topic-timer-info", {
      didInsertElement() {
        this._super(...arguments);
        
        // Handle bottom timer hiding for "Top" mode
        const topicController = api.container.lookup("controller:topic");
        if (!topicController?.model) return;
        
        const categoryId = topicController.model.category?.id;
        if (!categoryId) return;
        
        // Only apply to enabled categories
        if (!isCategoryEnabled(parseInt(categoryId, 10))) return;
        
        // If this is the bottom timer (not in custom container) and display mode is "Top", hide it
        if (displayLocation === "Top" && !this.element.closest(".custom-topic-timer-top")) {
          this.element.style.display = "none";
        }
      },
    });
  }

  // Set a body data attribute for CSS targeting
  document.body.setAttribute("data-topic-timer-location", settings.display_location);
});