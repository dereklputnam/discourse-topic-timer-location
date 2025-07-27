import { apiInitializer } from "discourse/lib/api";
import TopicTimerInfo from "discourse/components/topic-timer-info";
import { htmlSafe } from "@ember/template";
import { iconHTML } from "discourse-common/lib/icon-library";
import { action, computed } from "@ember/object";

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

  // Topic List Functionality
  
  // Add controller modifications for filtering and sorting
  api.modifyClass("controller:discovery/topics", {
    pluginId: "topic-timer-location",
    
    init() {
      this._super(...arguments);
      this.set("showTimerFilter", false);
      this.set("timerSort", null);
    },

    @action
    toggleTimerFilter() {
      this.toggleProperty("showTimerFilter");
      this.send("refresh");
    },

    @action
    sortByTimer(direction = "asc") {
      this.set("timerSort", direction);
      this.send("refresh");
    },

    @action
    clearTimerSort() {
      this.set("timerSort", null);
      this.send("refresh");
    },

    @computed("model.topics.@each.topic_timer")
    timerStats() {
      const topics = this.model?.topics || [];
      const withTimers = topics.filter(topic => 
        topic.topic_timer && 
        topic.topic_timer.status_type === "publish_to_category" &&
        isCategoryEnabled(topic.category?.id)
      );
      
      return {
        total: topics.length,
        withTimers: withTimers.length,
        percentage: topics.length > 0 ? Math.round((withTimers.length / topics.length) * 100) : 0
      };
    }
  });

  // Modify topic list to handle filtering and sorting
  api.modifyClass("model:topic-list", {
    pluginId: "topic-timer-location",
    
    @computed("topics.@each.topic_timer", "controller.showTimerFilter", "controller.timerSort")
    processedTopics() {
      let topics = this.topics || [];
      const controller = this.controller;
      
      // Apply timer filter
      if (controller && controller.showTimerFilter) {
        topics = topics.filter(topic => 
          topic.topic_timer && 
          topic.topic_timer.status_type === "publish_to_category" &&
          isCategoryEnabled(topic.category?.id)
        );
      }
      
      // Apply timer sorting
      if (controller && controller.timerSort) {
        topics = topics.slice().sort((a, b) => {
          const aHasTimer = a.topic_timer && 
                           a.topic_timer.status_type === "publish_to_category" &&
                           isCategoryEnabled(a.category?.id);
          const bHasTimer = b.topic_timer && 
                           b.topic_timer.status_type === "publish_to_category" &&
                           isCategoryEnabled(b.category?.id);
          
          if (controller.timerSort === "timers-first") {
            if (aHasTimer && !bHasTimer) return -1;
            if (!aHasTimer && bHasTimer) return 1;
            
            // Both have timers, sort by execution time
            if (aHasTimer && bHasTimer) {
              const aTime = new Date(a.topic_timer.execute_at);
              const bTime = new Date(b.topic_timer.execute_at);
              return aTime - bTime;
            }
          } else if (controller.timerSort === "execution-time") {
            // Sort only topics with timers by execution time
            if (aHasTimer && bHasTimer) {
              const aTime = new Date(a.topic_timer.execute_at);
              const bTime = new Date(b.topic_timer.execute_at);
              return aTime - bTime;
            }
          }
          
          return 0;
        });
      }
      
      return topics;
    }
  });

  // Add timer info display to topic list items
  api.decorateWidget("topic-list-item", (helper) => {
    const topic = helper.attrs.topic;
    if (!topic.topic_timer || 
        topic.topic_timer.status_type !== "publish_to_category" ||
        !isCategoryEnabled(topic.category?.id)) {
      return;
    }

    // Get destination category name
    const site = helper.register.lookup("site:main");
    const destinationCategory = site.categories.find(cat => cat.id === topic.topic_timer.category_id);
    const categoryName = destinationCategory ? destinationCategory.name : "Unknown";
    
    // Get parent category name if it's a subcategory
    let displayName = categoryName;
    if (destinationCategory?.parent_category_id) {
      const parent = site.categories.find(cat => cat.id === destinationCategory.parent_category_id);
      if (parent) {
        displayName = parent.name;
      }
    }
    
    const executeTime = topic.topic_timer.execute_at;
    const timeFromNow = executeTime ? moment(executeTime).fromNow() : "";
    
    const iconHtml = iconHTML("clock");
    
    // Add has-timer class to the topic list item
    const topicElement = helper.widget.element;
    if (topicElement) {
      topicElement.classList.add("has-timer");
    }
    
    return helper.attach("raw-html", {
      html: htmlSafe(`
        <span class="topic-timer-info">
          ${iconHtml}
          <span class="timer-destination">${displayName}</span>
          <span class="timer-time">${timeFromNow}</span>
        </span>
      `)
    });
  });

  // Add timer controls to topic list header
  api.decorateWidget("topic-list-header", (helper) => {
    const controller = helper.register.lookup("controller:discovery/topics");
    if (!controller) return;

    const stats = controller.timerStats || { total: 0, withTimers: 0, percentage: 0 };
    
    return helper.h("div.topic-timer-controls", [
      helper.h("div.timer-filter-controls", [
        helper.h("button.btn.btn-default.timer-filter-btn", {
          className: controller.showTimerFilter ? "active" : "",
          onclick: () => controller.send("toggleTimerFilter"),
          title: "Show only topics with timers"
        }, [
          helper.rawHtml(iconHTML("clock")),
          controller.showTimerFilter ? " Show All" : " Show Timers Only"
        ]),
        
        helper.h("select.timer-sort-select", {
          onchange: (e) => {
            const value = e.target.value;
            if (value === "") {
              controller.send("clearTimerSort");
            } else {
              controller.send("sortByTimer", value);
            }
          }
        }, [
          helper.h("option", { value: "" }, "Default Sort"),
          helper.h("option", { value: "timers-first" }, "Timers First"),
          helper.h("option", { value: "execution-time" }, "By Timer Date")
        ])
      ]),
      
      helper.h("div.timer-stats", [
        helper.h("span.stat-highlight", stats.withTimers.toString()),
        ` of ${stats.total} topics have timers (${stats.percentage}%)`
      ])
    ]);
  });
});
