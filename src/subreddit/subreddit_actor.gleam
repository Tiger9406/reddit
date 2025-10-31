
//sends back to user manager user id and post id once subreddit joined
import types
import gleam/otp/actor
import gleam/erlang/process
import gleam/set
import gleam/int
import gleam/io

pub fn subreddit_actor(state: types.SubredditState, message: types.SubredditMessage) -> actor.Next(types.SubredditState, types.SubredditMessage) {
  case message {
    types.SubredditAddSubscriber(username, user_actor) -> {
        let new_subs = set.insert(state.subscribers, username)
        let new_number_subs = state.number_of_subscribers + 1
        let new_state = types.SubredditState(..state, subscribers: new_subs, number_of_subscribers: new_number_subs)
        process.send(user_actor, types.UserJoinedSubreddit(state.name))
        actor.continue(new_state)
    }
    types.SubredditRemoveSubscriber(username, user_actor) -> {
        let new_subs = set.delete(state.subscribers, username)
        let new_number_subs = state.number_of_subscribers - 1
        let new_state = types.SubredditState(..state, subscribers: new_subs, number_of_subscribers: new_number_subs)
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
    types.SubredditCreatePost(post_id)->{
      let new_state = types.SubredditState(..state, posts: set.insert(state.posts, post_id))
      actor.continue(new_state)
    }
    types.SubredditPrintNumSubscribers()->{
      io.println("Subreddit "<> state.name <> " has " <> int.to_string(state.number_of_subscribers)<>" subscribers.")
      actor.continue(state)
    }
    types.SubredditGetLatestPosts(username, reply_to)->{
      let posts = state.posts
      process.send(reply_to, types.EngineReceiveUserFeed(username, posts))
      actor.continue(state)
    }
  }
}