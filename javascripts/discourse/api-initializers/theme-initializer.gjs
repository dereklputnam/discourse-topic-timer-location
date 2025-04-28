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

  // Helper to get parent category name
  const getParentCategoryName = (categoryId) => {
    if (!categoryId) return null;
    const site = api.container.lookup("site:main");
    const category = site.categories.find(c => c.id === categoryId);
    if (!category?.parent_category_id) return null;
    const parent = site.categories.find(c => c.id === category.parent_category_id);
    return parent ? parent.name : null;
  };

  // DOM manipulation: update only the link text in the timer
  function updateTimerLinkText(timerEl) {
    // Only update if this is a publish timer
    if (!timerEl.textContent.includes("will be published to")) return;
    // Find the link
    const link = timerEl.querySelector("a[href*='/c/']");
    if (!link) return;
    // Get category id from the link href
    const href = link.getAttribute("href");
    const match = href.match(/\/c\/(.+)\/(\d+)/);
    if (!match) return;
    const slug = match[1].split("/").pop();
    const id = parseInt(match[2], 10);
    const site = api.container.lookup("site:main");
    const category = site.categories.find(cat => cat.id === id && cat.slug === slug);
    if (!category?.parent_category_id) return;
    const parent = site.categories.find(cat => cat.id === category.parent_category_id);
    if (!parent) return;
    // Only update if the link text is not already the parent name
    if (link.textContent !== parent.name) {
      link.textContent = parent.name;
    }
  }

  // Observe for timer elements
  const observer = new MutationObserver((mutations) => {
    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach((node) => {
        if (node.nodeType === Node.ELEMENT_NODE) {
          if (node.classList.contains("topic-timer-info")) {
            updateTimerLinkText(node);
          } else {
            node.querySelectorAll && node.querySelectorAll(".topic-timer-info").forEach(updateTimerLinkText);
          }
        }
      });
    });
  });
  observer.observe(document.body, { childList: true, subtree: true });

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
