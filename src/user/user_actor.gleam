import gleam/otp/actor
import types.{type UserMessage, type UserState}
import gleam/set
import gleam/erlang/process

pub fn user_actor(state: UserState, message: UserMessage) -> actor.Next(UserState, UserMessage) {
  case message {
    types.UserUpdateKarma(delta) -> {
      let new_karma = state.karma + delta
      let new_state = types.UserState(
        state.username,
        new_karma,
        state.subscribed_subreddits,
        state.created_posts,
        state.created_comments,
        state.dm_conversations,
      )
      actor.continue(new_state)
    }

    types.UserGetAll(username, reply_to)->{
      process.send(reply_to, types.EngineReceiveUser(username, state))
      actor.continue(state)
    }

    types.UserJoinedSubreddit(subreddit_name) ->{
      let new_subs = set.insert(state.subscribed_subreddits, subreddit_name)
      let new_state = types.UserState(
          state.username,
          state.karma,
          new_subs,
          state.created_posts,
          state.created_comments,
          state.dm_conversations,
      )
      actor.continue(new_state)
    }
    types.UserLeftSubreddit(subreddit_name) ->{
        let new_subs = set.delete(state.subscribed_subreddits, subreddit_name)
        let new_state = types.UserState(
            state.username,
            state.karma,
            new_subs,
            state.created_posts,
            state.created_comments,
            state.dm_conversations,
        )
        actor.continue(new_state)
    }
    types.UserPostCreated(post_id) -> {
        let new_posts = set.insert(state.created_posts, post_id)
        let new_state = types.UserState(
            state.username,
            state.karma,
            state.subscribed_subreddits,
            new_posts,
            state.created_comments,
            state.dm_conversations,
        )
        actor.continue(new_state)
    }
    types.UserCommentCreated(comment_id) -> {
        let new_comments = set.insert(state.created_comments, comment_id)
        let new_state = types.UserState(
            state.username,
            state.karma,
            state.subscribed_subreddits,
            state.created_posts,
            new_comments,
            state.dm_conversations,
        )
        actor.continue(new_state)
    }
  }
}