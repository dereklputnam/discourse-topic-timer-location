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
    
    return enabledCategories.includes(categoryId);
  };

  if (renderTopTimer) {
    api.renderInOutlet("topic-above-posts", <template>
      {{#if @outletArgs.model.topic_timer}}
        <div class="custom-topic-timer-top" style="display: none;">
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

  // Apply our modifications after page load and DOM updates
  api.onPageChange(() => {
    requestAnimationFrame(() => {
      // Handle topic view modifications
      const topicController = api.container.lookup("controller:topic");
      if (topicController?.model) {
        const categoryId = topicController.model.category?.id;
        const hasTopic = !!topicController.model.topic_timer;
        
        // Convert to number for comparison
        const categoryIdNum = parseInt(categoryId, 10);
        console.log(`Topic Timer Location: Current category ID: ${categoryIdNum}`);
        console.log(`Topic Timer Location: Has topic timer: ${hasTopic}`);
        console.log(`Topic Timer Location: Display location: ${displayLocation}`);
        
        // Check if category is enabled or if all categories are enabled
        const shouldApply = enabledCategories.length === 0 || enabledCategories.includes(categoryIdNum);
        console.log(`Topic Timer Location: Should apply changes: ${shouldApply}`);
        
        if (!shouldApply || !hasTopic) {
          // Do nothing if not in enabled category or no topic timer
          return;
        }
        
        // Find our custom container
        const topContainer = document.querySelector(".custom-topic-timer-top");
        
        // Find the bottom timer
        const bottomTimer = document.querySelector(".topic-status-info .topic-timer-info");
        
        // Handle display location (Top, Bottom, Both)
        if (displayLocation === "Top") {
          console.log("Topic Timer Location: Enabling top-only display");
          
          // Ensure top container is created if it doesn't exist
          if (!topContainer && bottomTimer) {
            const newTopContainer = document.createElement("div");
            newTopContainer.className = "custom-topic-timer-top";
            
            // Clone the timer content
            const clonedTimer = bottomTimer.cloneNode(true);
            newTopContainer.appendChild(clonedTimer);
            
            // Insert before posts
            const postsContainer = document.querySelector(".topic-post, .posts-wrapper");
            if (postsContainer?.parentNode) {
              postsContainer.parentNode.insertBefore(newTopContainer, postsContainer);
            }
          }
          
          // Wait a tiny bit to ensure the DOM has updated
          setTimeout(() => {
            // Show top, hide bottom (make another attempt)
            if (topContainer) {
              topContainer.style.display = "";
            }
            
            // Find bottom timer again (might have been recreated)
            const bottomTimerAgain = document.querySelector(".topic-status-info .topic-timer-info");
            if (bottomTimerAgain) {
              bottomTimerAgain.style.display = "none";
            }
          }, 50);
        } else if (displayLocation === "Bottom") {
          console.log("Topic Timer Location: Enabling bottom-only display");
          
          // Hide top, show bottom
          if (topContainer) {
            topContainer.style.display = "none";
          }
          
          if (bottomTimer) {
            bottomTimer.style.display = "";
          }
        } else if (displayLocation === "Both") { 
          console.log("Topic Timer Location: Enabling both displays");
          
          // Ensure top container is created if it doesn't exist
          if (!topContainer && bottomTimer) {
            const newTopContainer = document.createElement("div");
            newTopContainer.className = "custom-topic-timer-top";
            
            // Clone the timer content
            const clonedTimer = bottomTimer.cloneNode(true);
            newTopContainer.appendChild(clonedTimer);
            
            // Insert before posts
            const postsContainer = document.querySelector(".topic-post, .posts-wrapper");
            if (postsContainer?.parentNode) {
              postsContainer.parentNode.insertBefore(newTopContainer, postsContainer);
            }
          }
          
          // Show both
          if (topContainer) {
            topContainer.style.display = "";
          }
          
          if (bottomTimer) {
            bottomTimer.style.display = "";
          }
        }
        
        // Always modify category links to use parent category name
        // and change "This topic" to "This announcement"
        if (shouldApply) {
          const allTimers = document.querySelectorAll(".topic-timer-info");
          const siteCategories = api.container.lookup("site:main").categories;

          allTimers.forEach((el) => {
            // Replace "This topic" with "This announcement"
            el.innerHTML = el.innerHTML.replace(/This topic/g, "This announcement");
            
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

            // Use parent category name instead of slug
            categoryLink.textContent = parent.name;
          });
        }
      }
    });
  });
});
