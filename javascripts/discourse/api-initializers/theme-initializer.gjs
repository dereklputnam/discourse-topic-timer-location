import { apiInitializer } from "discourse/lib/api";

export default apiInitializer("topic-timer-to-top", (api) => {
  const displayLocation = settings.display_location;
  const renderTopTimer = displayLocation === "Top" || displayLocation === "Both";
  const removeBottomTimer = displayLocation === "Top";

  // Parse allowed category IDs, converting to an array of integers
  const allowedCategoryIds = settings.allowed_category_ids
    ? settings.allowed_category_ids.split(',').map(id => parseInt(id.trim(), 10)).filter(id => !isNaN(id))
    : [];
    
  console.log("Topic Timer Location: Allowed category IDs:", allowedCategoryIds);

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
    console.log(`Topic Timer Location: Category ${numericCategoryId} allowed: ${allowed}`);
    return allowed;
  };

  // Function to handle topic timer display
  const handleTopicTimerDisplay = () => {
    // Get topic controller for category info
    const topicController = api.container.lookup("controller:topic");
    if (!topicController?.model?.topic_timer) return;
    
    const model = topicController.model;
    const categoryId = model.category?.id;
    
    // Check if this category is allowed
    if (!isCategoryAllowed(categoryId)) {
      console.log(`Topic Timer Location: Skipping category ${categoryId} (not in allowed list)`);
      return;
    }

    console.log(`Topic Timer Location: Handling display for category ${categoryId} with display location: ${displayLocation}`);
    
    // Original bottom timer
    const bottomTimer = document.querySelector(".topic-status-info .topic-timer-info");
    if (!bottomTimer) return;
    
    if (renderTopTimer) {
      // Create or get top timer container
      let topContainer = document.querySelector(".custom-topic-timer-top");
      if (!topContainer) {
        topContainer = document.createElement("div");
        topContainer.className = "custom-topic-timer-top";
        
        // Insert at the correct location
        const postsContainer = document.querySelector(".topic-post");
        const topicMap = document.querySelector(".topic-map");
        
        if (topicMap) {
          topicMap.parentNode.insertBefore(topContainer, topicMap);
        } else if (postsContainer?.parentNode) {
          postsContainer.parentNode.insertBefore(topContainer, postsContainer);
        }
      }
      
      // Clone the timer and add to top
      const clonedTimer = bottomTimer.cloneNode(true);
      // Clear the container first
      topContainer.innerHTML = "";
      topContainer.appendChild(clonedTimer);
    }
    
    // Handle bottom timer visibility
    if (displayLocation === "Top") {
      bottomTimer.style.display = "none";
    } else if (displayLocation === "Both") {
      bottomTimer.style.display = ""; // Show bottom timer
    }
  };

  // Function to handle parent category links
  const handleParentCategoryLinks = () => {
    if (!settings.use_parent_for_link) return;
    
    const topicController = api.container.lookup("controller:topic");
    if (!topicController?.model) return;
    
    const categoryId = topicController.model.category?.id;
    if (!isCategoryAllowed(categoryId)) return;
    
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
  };

  // Run our logic when the page changes
  api.onPageChange(() => {
    // Small delay to ensure the DOM is fully updated
    setTimeout(() => {
      handleTopicTimerDisplay();
      handleParentCategoryLinks();
    }, 100);
  });
});
