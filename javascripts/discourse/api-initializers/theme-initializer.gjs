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
  
  console.log("Topic Timer Location: Enabled categories:", enabledCategories);
  
  // Helper function to check if a category is enabled
  const isCategoryEnabled = (categoryId) => {
    // If no categories are specified, apply to all
    if (enabledCategories.length === 0) {
      return true;
    }
    
    const numericId = parseInt(categoryId, 10);
    const isEnabled = enabledCategories.includes(numericId);
    console.log(`Topic Timer Location: Category ${numericId} enabled: ${isEnabled}`);
    return isEnabled;
  };

  if (renderTopTimer) {
    // Original rendering logic
    const originalRenderInOutlet = api.renderInOutlet;
    
    // Override the renderInOutlet method
    api.renderInOutlet = function(outletName, fn) {
      if (outletName === "topic-above-posts") {
        // Custom implementation that checks category
        return originalRenderInOutlet.call(this, outletName, function(outletArgs) {
          const model = outletArgs.model;
          const categoryId = model?.category?.id;
          
          // Check if this topic is in an enabled category
          if (!isCategoryEnabled(categoryId)) {
            console.log(`Topic Timer Location: Skipping top timer for category ${categoryId}`);
            return "";
          }
          
          // Original template
          if (model.topic_timer) {
            return `
              <div class="custom-topic-timer-top">
                ${originalRenderInOutlet.call(this, "topic-timer-info", {
                  topicClosed: model.closed,
                  statusType: model.topic_timer.status_type,
                  statusUpdate: model.topic_status_update,
                  executeAt: model.topic_timer.execute_at,
                  basedOnLastPost: model.topic_timer.based_on_last_post,
                  durationMinutes: model.topic_timer.duration_minutes,
                  categoryId: model.topic_timer.category_id
                })}
              </div>
            `;
          }
          
          return "";
        });
      }
      
      // Default for other outlets
      return originalRenderInOutlet.call(this, outletName, fn);
    };
  }

  if (removeBottomTimer) {
    api.modifyClass("component:topic-timer-info", {
      didInsertElement() {
        this._super(...arguments);
        
        const topicController = api.container.lookup("controller:topic");
        const categoryId = topicController?.model?.category?.id;
        
        // Skip if not in an enabled category
        if (!isCategoryEnabled(categoryId)) {
          console.log(`Topic Timer Location: Skipping bottom timer removal for category ${categoryId}`);
          return;
        }
        
        // Only remove bottom timer (not in custom container)
        if (!this.element.closest(".custom-topic-timer-top")) {
          console.log(`Topic Timer Location: Removing bottom timer for category ${categoryId}`);
          this.element.style.display = "none";
        }
      },
    });
  }

  if (settings.use_parent_for_link) {
    api.onPageChange(() => {
      requestAnimationFrame(() => {
        const topicController = api.container.lookup("controller:topic");
        const categoryId = topicController?.model?.category?.id;
        
        // Skip if not in an enabled category
        if (!isCategoryEnabled(categoryId)) {
          console.log(`Topic Timer Location: Skipping parent link for category ${categoryId}`);
          return;
        }
        
        console.log(`Topic Timer Location: Processing parent links for category ${categoryId}`);
        
        const allTimers = document.querySelectorAll(".topic-timer-info");
        const siteCategories = api.container.lookup("site:main").categories;

        allTimers.forEach((el) => {
          const text = el.textContent?.trim();
          if (!text?.includes("will be published to")) return;

          const categoryLink = el.querySelector("a[href*='/c/']");
          if (!categoryLink) return;

          const href = categoryLink.getAttribute("href");
          const match = href.match(/\/c\/(.+)\/(\d+)/);
          if (!match) return;

          const fullSlug = match[1];
          const slug = fullSlug.split("/").pop();
          const id = parseInt(match[2], 10);

          const category = siteCategories.find((cat) => cat.id === id && cat.slug === slug);
          if (!category?.parent_category_id) return;

          const parent = siteCategories.find((cat) => cat.id === category.parent_category_id);
          if (!parent) return;

          categoryLink.textContent = `#${parent.slug}`;
        });
      });
    });
  }
});
