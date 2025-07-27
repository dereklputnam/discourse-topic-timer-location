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
    try {
      // Only update if this is a publish timer
      if (!timerEl || !timerEl.textContent || !timerEl.textContent.includes("will be published to")) return;
      
      // Get the current category ID from the topic
      const topicController = api.container.lookup("controller:topic");
      if (!topicController?.model?.category?.id) return;
      
      const currentCategoryId = parseInt(topicController.model.category.id, 10);
      
      // Check if current category is enabled in settings
      if (!isCategoryEnabled(currentCategoryId)) return;
      
      // Find the link
      const link = timerEl.querySelector("a[href*='/c/']");
      if (!link) return;
      
      // Get category id from the link href
      const href = link.getAttribute("href");
      if (!href) return;
      
      const match = href.match(/\/c\/(.+)\/(\d+)/);
      if (!match || match.length < 3) return;
      
      const slug = match[1]?.split("/")?.pop();
      const id = parseInt(match[2], 10);
      if (!slug || isNaN(id)) return;
      
      const site = api.container.lookup("site:main");
      if (!site?.categories) return;
      
      const category = site.categories.find(cat => cat.id === id && cat.slug === slug);
      if (!category?.parent_category_id) return;
      
      const parent = site.categories.find(cat => cat.id === category.parent_category_id);
      if (!parent?.name) return;
      
      // Only update if the link text is not already the parent name
      if (link.textContent !== parent.name) {
        link.textContent = parent.name;
      }
    } catch (error) {
      // Silently handle any errors
      console.warn("Timer link text update error:", error);
    }
  }

  // Observe for timer elements
  const observer = new MutationObserver((mutations) => {
    try {
      mutations.forEach((mutation) => {
        if (!mutation.addedNodes) return;
        
        mutation.addedNodes.forEach((node) => {
          if (!node || node.nodeType !== Node.ELEMENT_NODE) return;
          
          try {
            if (node.classList && node.classList.contains("topic-timer-info")) {
              updateTimerLinkText(node);
            } else if (node.querySelectorAll) {
              const timerElements = node.querySelectorAll(".topic-timer-info");
              timerElements.forEach(updateTimerLinkText);
            }
          } catch (nodeError) {
            // Skip problematic nodes
            console.warn("Node processing error:", nodeError);
          }
        });
      });
    } catch (error) {
      console.warn("MutationObserver error:", error);
    }
  });
  
  try {
    observer.observe(document.body, { childList: true, subtree: true });
  } catch (error) {
    console.warn("Failed to start MutationObserver:", error);
  }

  if (renderTopTimer) {
    api.renderInOutlet("topic-above-posts", <template>
      {{#if @outletArgs.model.topic_timer}}
        {{#if (isCategoryEnabled @outletArgs.model.category.id)}}
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

  // Additional cleanup for bottom timer when in "Top" mode
  if (removeBottomTimer) {
    api.modifyClass("component:topic-timer-info", {
      didInsertElement() {
        this._super(...arguments);
        
        // Handle bottom timer hiding for "Top" mode
        const topicController = api.container.lookup("controller:topic");
        if (!topicController?.model) return;
        
        const categoryId = topicController.model.category?.id;
        if (!categoryId) return;
        
        // Only apply to enabled categories
        if (!isCategoryEnabled(parseInt(categoryId, 10))) return;
        
        // If this is the bottom timer (not in custom container) and display mode is "Top", hide it
        if (displayLocation === "Top" && !this.element.closest(".custom-topic-timer-top")) {
          this.element.style.display = "none";
        }
      },
    });
  }

  // Set a body data attribute for CSS targeting
  document.body.setAttribute("data-topic-timer-location", settings.display_location);
  
  // Proactive timer data fetching
  const fetchQueue = new Set();
  let fetchTimeout = null;
  
  function fetchTopicTimerData(topicIds) {
    if (topicIds.length === 0) return;
    
    // Batch API calls to avoid overwhelming the server
    const batchSize = 10;
    const batches = [];
    for (let i = 0; i < topicIds.length; i += batchSize) {
      batches.push(topicIds.slice(i, i + batchSize));
    }
    
    batches.forEach(batch => {
      batch.forEach(topicId => {
        // Use Discourse's ajax helper to fetch topic data
        const ajax = api.container.lookup('service:ajax');
        if (!ajax) return;
        
        ajax.request(`/t/${topicId}.json`, {
          type: 'GET',
          cache: true
        }).then(data => {
          if (data.topic_timer) {
            // Store the timer data for later use
            const store = api.container.lookup('service:store');
            if (store) {
              try {
                // Update the cached topic with timer data
                const topic = store.peekRecord('topic', topicId);
                if (topic) {
                  topic.set('topic_timer', data.topic_timer);
                }
              } catch (e) {
                console.warn('Failed to update topic cache:', e);
              }
            }
            
            // Trigger badge update
            setTimeout(() => addTimerBadgesToTopicList(), 100);
          }
        }).catch(error => {
          // Silently handle API errors to avoid console spam
          if (error.status !== 403 && error.status !== 404) {
            console.warn('Failed to fetch topic timer data:', error);
          }
        });
      });
    });
  }
  
  function queueTimerDataFetch(topicId) {
    fetchQueue.add(topicId);
    
    // Debounce API calls
    if (fetchTimeout) clearTimeout(fetchTimeout);
    fetchTimeout = setTimeout(() => {
      const ids = Array.from(fetchQueue);
      fetchQueue.clear();
      fetchTopicTimerData(ids);
    }, 500);
  }
  
  // Simple approach: Add timer badges to topic lists using DOM manipulation
  function addTimerBadgesToTopicList() {
    const topicRows = document.querySelectorAll('.topic-list-item');
    
    topicRows.forEach(row => {
      // Skip if already processed
      if (row.hasAttribute('data-timer-processed')) return;
      row.setAttribute('data-timer-processed', 'true');
      
      // Get topic ID from the row
      const topicId = row.getAttribute('data-topic-id');
      if (!topicId) return;
      
      // Look for existing timer badge to avoid duplicates
      if (row.querySelector('.topic-timer-badge')) return;
      
      // Find the topic title area
      const titleLink = row.querySelector('.raw-topic-link, .title');
      if (!titleLink) return;
      
      let topic = null;
      let timerData = null;
      
      // Method 1: Try to get topic data from Discourse's topic list controller
      const topicListController = api.container.lookup('controller:discovery/topics');
      if (topicListController?.model?.topics) {
        topic = topicListController.model.topics.find(t => t.id == topicId);
        if (topic?.topic_timer) {
          timerData = topic.topic_timer;
        }
      }
      
      // Method 2: Try to get from topic store (may have cached data)
      if (!timerData) {
        try {
          const store = api.container.lookup('service:store');
          const cachedTopic = store.peekRecord('topic', topicId);
          if (cachedTopic?.topic_timer) {
            timerData = cachedTopic.topic_timer;
            topic = cachedTopic;
          }
        } catch (e) {
          // Store lookup failed, continue to other methods
        }
      }
      
      // Method 3: Check if there's timer data in the DOM (from server-rendered data)
      if (!timerData) {
        // Look for data attributes or JSON that might contain timer info
        const topicData = row.querySelector('[data-topic-timer]');
        if (topicData) {
          try {
            timerData = JSON.parse(topicData.getAttribute('data-topic-timer'));
          } catch (e) {
            // JSON parsing failed
          }
        }
      }
      
      // If we still don't have timer data, queue a fetch and skip for now
      if (!timerData) {
        // Queue this topic for API fetching
        queueTimerDataFetch(topicId);
        return;
      }
      
      // Check if this timer is relevant
      if (timerData.status_type !== 'publish_to_category' ||
          !isCategoryEnabled(topic?.category_id || timerData.category_id)) {
        return;
      }
      
      // Create and add the timer badge
      const badge = document.createElement('span');
      badge.className = 'topic-timer-badge';
      badge.textContent = moment(timerData.execute_at).fromNow();
      
      // Insert after the title link
      titleLink.parentNode.insertBefore(badge, titleLink.nextSibling);
    });
  }
  
  // Run when topic lists load
  const listObserver = new MutationObserver((mutations) => {
    let shouldCheck = false;
    mutations.forEach((mutation) => {
      mutation.addedNodes.forEach((node) => {
        if (node.nodeType === Node.ELEMENT_NODE && 
            (node.classList?.contains('topic-list') || 
             node.querySelector && node.querySelector('.topic-list'))) {
          shouldCheck = true;
        }
      });
    });
    
    if (shouldCheck) {
      setTimeout(addTimerBadgesToTopicList, 100);
    }
  });
  
  try {
    listObserver.observe(document.body, { childList: true, subtree: true });
    // Also run on initial page load
    setTimeout(addTimerBadgesToTopicList, 500);
  } catch (error) {
    console.warn("Topic list timer observer error:", error);
  }
});