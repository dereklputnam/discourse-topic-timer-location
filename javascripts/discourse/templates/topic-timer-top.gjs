import Component from "@glimmer/component";
import TopicTimerInfo from "discourse/components/topic-timer-info";

export default class TopicTimerTop extends Component {
  get reminderText() {
    return settings.reminder_text;
  }

  <template>
    {{#if @outletArgs.model.topic_timer}}
      <div class="custom-topic-timer-top">
        {{#if this.reminderText}}
          <p class="custom-topic-timer-top__reminder"><strong>{{this.reminderText}}</strong></p>
        {{/if}}
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
}
