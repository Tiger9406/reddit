
//sends back to user manager user id and post id once subreddit joined
import types
import gleam/otp/actor
import gleam/erlang/process
import gleam/set

pub fn subreddit_actor(state: types.SubredditState, message: types.SubredditMessage) -> actor.Next(types.SubredditState, types.SubredditMessage) {
  case message {
    types.SubredditAddSubscriber(username, user_actor) -> {
        let new_subs = set.insert(state.subscribers, username)
        let new_number_subs = state.number_of_subscribers + 1
        let new_state = types.SubredditState(
            state.name,
            state.description,
            new_subs,
            state.posts,
            new_number_subs,
            state.number_posts,
        )
        process.send(user_actor, types.UserJoinedSubreddit(state.name))
        actor.continue(new_state)
    }
    types.SubredditRemoveSubscriber(username, user_actor) -> {
        let new_subs = set.delete(state.subscribers, username)
        let new_number_subs = state.number_of_subscribers - 1
        let new_state = types.SubredditState(
            state.name,
            state.description,
            new_subs,
            state.posts,
            new_number_subs,
            state.number_posts,
        )
        process.send(user_actor, types.UserLeftSubreddit(state.name))
        actor.continue(new_state)
    }
    types.SubredditGetAll(username, reply_to) -> {
        process.send(reply_to, types.EngineReceiveSubredditDetails(
          username, 
          state
        ))
        actor.continue(state)
    }
    //handle messages here
    _ -> {
      actor.continue(state)
    }
  }
}