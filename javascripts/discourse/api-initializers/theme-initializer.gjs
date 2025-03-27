import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("topic-timer-to-top", (api) => {
  // Log the settings for debugging
  console.log("Topic Timer Location: Settings loaded", {
    displayLocation: settings.display_location,
    useParentForLink: settings.use_parent_for_link,
    allowedCategoryIds: settings.allowed_category_ids
  });

  // Parse allowed category IDs, converting to an array of integers
  const allowedCategoryIds = settings.allowed_category_ids
    ? settings.allowed_category_ids.split(',').map(id => parseInt(id.trim(), 10)).filter(id => !isNaN(id))
    : [];
    
  console.log("Topic Timer Location: Parsed category IDs:", allowedCategoryIds);

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
    return allowedCategoryIds.includes(numericCategoryId);
  };

  // Apply our modifications after page load and DOM updates
  api.onPageChange(() => {
    // Get topic controller
    const topicController = api.container.lookup("controller:topic");
    if (!topicController?.model) {
      console.log("Topic Timer Location: No topic model found, skipping");
      return;
    }
    
    const topicModel = topicController.model;
    const categoryId = topicModel.category?.id;
    
    console.log("Topic Timer Location: Current topic category:", categoryId);
    
    // Check if category is allowed
    if (!isCategoryAllowed(categoryId)) {
      console.log(`Topic Timer Location: Category ${categoryId} not in allowed list, skipping`);
      return;
    }
    
    // Only proceed if we have a topic timer
    if (!topicModel.topic_timer) {
      console.log("Topic Timer Location: No topic timer found, skipping");
      return;
    }
    
    console.log(`Topic Timer Location: Processing category ${categoryId} with display location: ${settings.display_location}`);
    
    // Wait for DOM to be ready
    setTimeout(() => {
      applyTimerLocation();
      
      if (settings.use_parent_for_link) {
        applyParentCategoryLinks();
      }
    }, 500);
  });
  
  // Function to apply timer location changes
  const applyTimerLocation = () => {
    // Find the original timer
    const originalTimer = document.querySelector(".topic-status-info .topic-timer-info");
    if (!originalTimer) {
      console.log("Topic Timer Location: No timer element found in the DOM");
      return;
    }
    
    console.log("Topic Timer Location: Original timer found in DOM");
    
    // Handle different display locations
    if (settings.display_location === "Top" || settings.display_location === "Both") {
      // Create a container for the top timer
      let topContainer = document.querySelector(".custom-topic-timer-top");
      if (!topContainer) {
        topContainer = document.createElement("div");
        topContainer.className = "custom-topic-timer-top";
        
        // Find a good place to insert it
        const topicTimeline = document.querySelector(".topic-timeline");
        const postsContainer = document.querySelector(".posts-wrapper");
        const topicMap = document.querySelector(".topic-map");
        
        let inserted = false;
        
        // Try different insertion points
        if (topicMap && topicMap.parentNode) {
          console.log("Topic Timer Location: Inserting before topic-map");
          topicMap.parentNode.insertBefore(topContainer, topicMap);
          inserted = true;
        } else if (postsContainer) {
          console.log("Topic Timer Location: Inserting before posts-wrapper");
          postsContainer.parentNode.insertBefore(topContainer, postsContainer);
          inserted = true;
        } else if (topicTimeline && topicTimeline.parentNode) {
          console.log("Topic Timer Location: Inserting before topic-timeline");
          topicTimeline.parentNode.insertBefore(topContainer, topicTimeline);
          inserted = true;
        }
        
        if (!inserted) {
          console.log("Topic Timer Location: Could not find insertion point, giving up");
          return;
        }
      } else {
        console.log("Topic Timer Location: Top container already exists");
      }
      
      // Clone the timer into the top container
      const clonedTimer = originalTimer.cloneNode(true);
      topContainer.innerHTML = "";
      topContainer.appendChild(clonedTimer);
      console.log("Topic Timer Location: Timer cloned to top container");
      
      // Hide original if display location is Top only
      if (settings.display_location === "Top") {
        originalTimer.style.display = "none";
        console.log("Topic Timer Location: Original timer hidden");
      } else {
        originalTimer.style.display = "";
        console.log("Topic Timer Location: Both timers visible");
      }
    } else if (settings.display_location === "Bottom") {
      // Remove top timer if it exists
      const topContainer = document.querySelector(".custom-topic-timer-top");
      if (topContainer) {
        topContainer.remove();
        console.log("Topic Timer Location: Removed top container for Bottom-only display");
      }
      
      // Make sure original timer is visible
      originalTimer.style.display = "";
    }
  };
  
  // Function to apply parent category links
  const applyParentCategoryLinks = () => {
    console.log("Topic Timer Location: Processing parent category links");
    
    const allTimers = document.querySelectorAll(".topic-timer-info");
    if (!allTimers.length) {
      console.log("Topic Timer Location: No timers found for parent category processing");
      return;
    }
    
    const siteCategories = api.container.lookup("site:main").categories;
    if (!siteCategories) {
      console.log("Topic Timer Location: Could not access site categories");
      return;
    }

    let modified = 0;
    
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
      modified++;
    });
    
    console.log(`Topic Timer Location: Modified ${modified} parent category links`);
  };
});
