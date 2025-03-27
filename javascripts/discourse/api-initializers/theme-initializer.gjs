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

  if (renderTopTimer) {
    api.renderInOutlet("topic-above-posts", function(outletArgs) {
      const model = outletArgs.model;
      
      // Check if topic timer exists and category is allowed
      if (model.topic_timer && 
          (allowedCategoryIds.length === 0 || 
           allowedCategoryIds.includes(model.category.id))) {
        return this.renderToString(<div class="custom-topic-timer-top">
          <TopicTimerInfo
            topicClosed={model.closed}
            statusType={model.topic_timer.status_type}
            statusUpdate={model.topic_status_update}
            executeAt={model.topic_timer.execute_at}
            basedOnLastPost={model.topic_timer.based_on_last_post}
            durationMinutes={model.topic_timer.duration_minutes}
            categoryId={model.topic_timer.category_id}
          />
        </div>);
      }
      
      return null;
    });
  }

  if (removeBottomTimer) {
    api.modifyClass("component:topic-timer-info", {
      didInsertElement() {
        const topicCategoryId = this.args.categoryId;
        
        // Only remove if not in top location and not in allowed categories
        if (!this.element.closest(".custom-topic-timer-top") && 
            (allowedCategoryIds.length > 0 && 
             !allowedCategoryIds.includes(topicCategoryId))) {
          this.element.remove();
        }
      },
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
