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
    
  console.log("Allowed category IDs:", allowedCategoryIds);

  // Function to check if a category ID is allowed
  const isCategoryAllowed = (categoryId) => {
    // If no category IDs specified, allow all categories
    if (!allowedCategoryIds.length) {
      return true;
    }
    
    // Make sure we have a valid category ID (convert to number if needed)
    const numericCategoryId = parseInt(categoryId, 10);
    if (isNaN(numericCategoryId)) {
      return false;
    }
    
    // Check if category ID is in the allowed list
    const allowed = allowedCategoryIds.includes(numericCategoryId);
    console.log(`Category ${numericCategoryId} allowed: ${allowed}`);
    return allowed;
  };

  if (renderTopTimer) {
    api.decorateWidget("topic-above-posts:before", (helper) => {
      const topicModel = helper.getModel();
      
      // Only show timer if topic has timer and category is allowed
      if (topicModel?.topic_timer && isCategoryAllowed(topicModel.category?.id)) {
        return helper.h('div.custom-topic-timer-top', [
          helper.attach('topic-timer-info', {
            topicClosed: topicModel.closed,
            statusType: topicModel.topic_timer.status_type,
            statusUpdate: topicModel.topic_status_update,
            executeAt: topicModel.topic_timer.execute_at,
            basedOnLastPost: topicModel.topic_timer.based_on_last_post,
            durationMinutes: topicModel.topic_timer.duration_minutes,
            categoryId: topicModel.topic_timer.category_id
          })
        ]);
      }
    });
  }

  if (removeBottomTimer) {
    api.reopenWidget("topic-timer-info", {
      buildAttributes(attrs) {
        const topicController = api.container.lookup("controller:topic");
        const topicModel = topicController?.model;
        
        // If we're in a topic and can get the category ID
        if (topicModel?.category?.id !== undefined) {
          // Hide the default bottom timer if category is not allowed
          if (!isCategoryAllowed(topicModel.category.id)) {
            return { style: "display: none;" };
          }
        }
        
        return this._super(...arguments);
      }
    });
    
    api.onPageChange(() => {
      // Wait a moment for the DOM to update
      setTimeout(() => {
        // Remove bottom timers but leave top timers alone
        const bottomTimers = document.querySelectorAll(".topic-timer-info:not(.custom-topic-timer-top .topic-timer-info)");
        
        bottomTimers.forEach((timerElement) => {
          // Get the current topic from the controller
          const topicController = api.container.lookup("controller:topic");
          const topicModel = topicController?.model;
          
          // Check if we should hide this timer based on category
          if (topicModel?.category?.id !== undefined && !isCategoryAllowed(topicModel.category.id)) {
            timerElement.style.display = "none";
          }
        });
      }, 100);
    });
  }

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
