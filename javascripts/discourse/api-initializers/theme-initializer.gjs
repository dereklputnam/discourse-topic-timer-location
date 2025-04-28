import { apiInitializer } from "discourse/lib/api";
import TopicTimerInfo from "discourse/components/topic-timer-info";

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

  // Helper function to get display name for a category
  const getDisplayName = (categoryId) => {
    if (!categoryId) return "";
    const site = api.container.lookup("site:main");
    const category = site.categories.find(c => c.id === categoryId);
    if (!category) return "";
    if (category.parent_category_id) {
      const parent = site.categories.find(c => c.id === category.parent_category_id);
      if (parent) {
        return `${parent.name} ${category.name}`;
      }
    }
    return category.name;
  };

  // Override the timer text computation
  api.modifyClass("component:topic-timer-info", {
    pluginId: "topic-timer-location",
    
    // Override the text computation method
    _computeText() {
      const result = this._super(...arguments);
      
      // Only modify text for publishing timers
      if (!result?.includes("will be published to")) {
        return result;
      }
      
      // Get the category ID from the model
      const categoryId = this.categoryId;
      if (!categoryId) return result;
      
      // Look up the category and its parent
      const site = api.container.lookup("site:main");
      const category = site.categories.find(c => c.id === categoryId);
      if (!category?.parent_category_id) return result;
      
      const parent = site.categories.find(c => c.id === category.parent_category_id);
      if (!parent) return result;
      
      // Replace the category name with the parent name
      return result.replace(/#[^ ]+/, parent.name);
    }
  });

  if (renderTopTimer) {
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

  // Additional cleanup for bottom timer when in "Top" mode
  if (removeBottomTimer) {
    api.modifyClass("component:topic-timer-info", {
      didInsertElement() {
        this._super(...arguments);
        
        // Handle bottom timer hiding for "Top" mode
        const topicController = api.container.lookup("controller:topic");
        if (!topicController?.model) return;
        
        const categoryId = topicController.model.category?.id;
        const categoryIdNum = parseInt(categoryId, 10);
        
        // Only apply to enabled categories
        const shouldApply = enabledCategories.length === 0 || enabledCategories.includes(categoryIdNum);
        if (!shouldApply) return;
        
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
