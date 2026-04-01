import TopicTimerInfo from "discourse/components/topic-timer-info";

<template>
  {{#if @outletArgs.model.topic_timer}}
    <div class="custom-topic-timer-top">
      <p class="custom-topic-timer-top__reminder"><strong>Don't forget, this isn't public yet!</strong></p>
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
</template>
