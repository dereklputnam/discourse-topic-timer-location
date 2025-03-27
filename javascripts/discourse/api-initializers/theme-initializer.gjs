import { apiInitializer } from "discourse/lib/api";
import TopicTimerInfo from "discourse/components/topic-timer-info";

export default apiInitializer("topic-timer-to-top", (api) => {
  const displayLocation = settings.display_location;
  const renderTopTimer = displayLocation === "Top" || displayLocation === "Both";
  const removeBottomTimer = displayLocation === "Top";

  // Parse allowed category IDs, converting to an array of integers
  const allowedCategoryIds = settings.allowed_category_ids
    ? settings.allowed_category_ids.split(',').map(id => parseInt(id.trim(), 10)).filter(id => !isNaN(id))
    : [];

  // Function to check if a category is allowed
  const isAllowedCategory = (topicCategoryId) => {
    // If no category IDs specified, allow all categories
    if (allowedCategoryIds.length === 0) return true;
    
    // Check if topic's category ID is in the allowed list
    return allowedCategoryIds.includes(topicCategoryId);
  };

  if (renderTopTimer) {
    api.renderInOutlet("topic-above-posts", <template>
      {{#if @outletArgs.model.topic_timer}}
        {{#if (isAllowedCategory @outletArgs.model.category.id)}}
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
      {{/if}}
    </template>);
  }

  if (removeBottomTimer) {
    api.modifyClass("component:topic-timer-info", {
      didInsertElement() {
        const topicCategoryId = this.args.categoryId;
        
        // Only remove if not in top location and not in allowed categories
        if (!this.element.closest(".custom-topic-timer-top") && 
            !isAllowedCategory(topicCategoryId)) {
          this.element.remove();
        }
      },
    });
  }

  // Rest of the existing code remains the same...
  if (settings.use_parent_for_link) {
    api.onPageChange(() => {
      requestAnimationFrame(() => {
        const allTimers = document.querySelectorAll(".topic-timer-info");

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
          const siteCategories = api.container.lookup("site:main").categories;

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
