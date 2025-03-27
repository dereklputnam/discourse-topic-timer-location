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

  // Handle category filtering through DOM manipulation
  api.onPageChange(() => {
    requestAnimationFrame(() => {
      const topicController = api.container.lookup("controller:topic");
      const categoryId = topicController?.model?.category?.id;
      
      // Convert to number for comparison
      const categoryIdNum = parseInt(categoryId, 10);
      console.log(`Topic Timer Location: Current category ID: ${categoryIdNum}`);
      
      // Check if category is enabled or if all categories are enabled
      const shouldApply = enabledCategories.length === 0 || enabledCategories.includes(categoryIdNum);
      console.log(`Topic Timer Location: Should apply changes: ${shouldApply}`);
      
      // Find our custom container
      const topContainer = document.querySelector(".custom-topic-timer-top");
      
      // Find the bottom timer
      const bottomTimer = document.querySelector(".topic-status-info .topic-timer-info");
      
      if (!shouldApply) {
        // If not enabled, hide top container and ensure bottom is visible
        if (topContainer) {
          topContainer.style.display = "none";
        }
        
        if (bottomTimer) {
          bottomTimer.style.display = "";
        }
      } else {
        // Handle display location
      if (shouldApply) {
        console.log(`Topic Timer Location: Display location setting: ${displayLocation}`);
        
        // If enabled, show/hide according to display location
        if (topContainer) {
          if (displayLocation === "Top" || displayLocation === "Both") {
            // Show top container
            topContainer.style.display = "";
          } else {
            // Hide top container
            topContainer.style.display = "none";
          }
        }
        
        // Handle bottom timer according to settings
        if (bottomTimer) {
          if (displayLocation === "Bottom" || displayLocation === "Both") {
            // Show bottom timer
            bottomTimer.style.display = "";
          } else {
            // Hide bottom timer
            bottomTimer.style.display = "none";
          }
        }
        
        // Handle parent link replacement if enabled
        if (settings.use_parent_for_link) {
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
        }
      }
    });
  });

  // This is still necessary to create the initial element
  if (removeBottomTimer) {
    api.modifyClass("component:topic-timer-info", {
      didInsertElement() {
        this._super(...arguments);
        
        // Actual display/hiding now handled in onPageChange
      },
    });
  }
});
