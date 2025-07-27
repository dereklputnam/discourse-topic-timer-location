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
  
  // Enhanced timer data fetching - category-specific approach
  const fetchQueue = new Map(); // topicId -> categoryId mapping
  let fetchTimeout = null;
  
  function fetchCategoryTimerData(categoryId, topicIds) {
    if (!isCategoryEnabled(categoryId) || topicIds.length === 0) return;
    
    const ajax = api.container.lookup('service:ajax');
    if (!ajax) return;
    
    // Try category-specific endpoint first (if it exists)
    ajax.request(`/c/${categoryId}.json`, {
      type: 'GET',
      cache: true
    }).then(categoryData => {
      // If category data includes topic timers, use that
      if (categoryData.topic_list?.topics) {
        const store = api.container.lookup('service:store');
        categoryData.topic_list.topics.forEach(topicData => {
          if (topicData.id && topicIds.includes(topicData.id) && topicData.topic_timer) {
            try {
              const topic = store?.peekRecord('topic', topicData.id);
              if (topic) {
                topic.set('topic_timer', topicData.topic_timer);
              }
            } catch (e) {
              console.warn('Failed to update topic cache from category data:', e);
            }
          }
        });
        setTimeout(() => addTimerBadgesToTopicList(), 100);
        return;
      }
      
      // Fallback to individual topic fetching
      fetchIndividualTopics(topicIds);
    }).catch(() => {
      // Category endpoint failed, fallback to individual topics
      fetchIndividualTopics(topicIds);
    });
  }
  
  function fetchIndividualTopics(topicIds) {
    const ajax = api.container.lookup('service:ajax');
    if (!ajax) return;
    
    // Batch individual topic requests
    const batchSize = 5; // Smaller batch size for individual requests
    const batches = [];
    for (let i = 0; i < topicIds.length; i += batchSize) {
      batches.push(topicIds.slice(i, i + batchSize));
    }
    
    batches.forEach((batch, batchIndex) => {
      // Stagger batch requests to be server-friendly
      setTimeout(() => {
        batch.forEach(topicId => {
          ajax.request(`/t/${topicId}.json`, {
            type: 'GET',
            cache: true
          }).then(data => {
            if (data.topic_timer) {
              const store = api.container.lookup('service:store');
              if (store) {
                try {
                  const topic = store.peekRecord('topic', topicId);
                  if (topic) {
                    topic.set('topic_timer', data.topic_timer);
                  }
                } catch (e) {
                  console.warn('Failed to update topic cache:', e);
                }
              }
              setTimeout(() => addTimerBadgesToTopicList(), 100);
            }
          }).catch(error => {
            // Silently handle API errors for non-critical failures
            if (error.status !== 403 && error.status !== 404 && error.status !== 429) {
              console.warn('Failed to fetch topic timer data:', error);
            }
          });
        });
      }, batchIndex * 200); // 200ms delay between batches
    });
  }
  
  function queueTimerDataFetch(topicId, categoryId) {
    fetchQueue.set(topicId, categoryId);
    
    // Debounce API calls
    if (fetchTimeout) clearTimeout(fetchTimeout);
    fetchTimeout = setTimeout(() => {
      const entries = Array.from(fetchQueue.entries());
      fetchQueue.clear();
      
      // Group topics by category
      const categoriesMap = new Map();
      entries.forEach(([topicId, catId]) => {
        if (!categoriesMap.has(catId)) {
          categoriesMap.set(catId, []);
        }
        categoriesMap.get(catId).push(topicId);
      });
      
      // Fetch by category
      categoriesMap.forEach((topicIds, categoryId) => {
        fetchCategoryTimerData(categoryId, topicIds);
      });
    }, 750); // Slightly longer debounce for better batching
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
        // Get category ID for targeted fetching
        const categoryId = topic?.category_id || 
                          (row.querySelector('[data-category-id]')?.getAttribute('data-category-id'));
        
        if (categoryId && isCategoryEnabled(parseInt(categoryId))) {
          queueTimerDataFetch(topicId, parseInt(categoryId));
        }
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