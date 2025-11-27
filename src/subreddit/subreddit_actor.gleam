
//sends back to user manager user id and post id once subreddit joined
import gleam/json
import types
import gleam/otp/actor
import gleam/erlang/process
import gleam/set
import gleam/int
import gleam/io

pub fn subreddit_actor(state: types.SubredditState, message: types.SubredditMessage) -> actor.Next(types.SubredditState, types.SubredditMessage) {
  case message {
    types.SubredditAddSubscriber(username, user_actor, reply_to) -> {
        let new_subs = set.insert(state.subscribers, username)
        let new_number_subs = state.number_of_subscribers + 1
        let new_state = types.SubredditState(..state, subscribers: new_subs, number_of_subscribers: new_number_subs)
        process.send(user_actor, types.UserJoinedSubreddit(state.name))
        process.send(reply_to, Ok("Subscribed to subreddit "<> state.name))
        actor.continue(new_state)
    }
    types.SubredditRemoveSubscriber(username, user_actor, reply_to) -> {
        let new_subs = set.delete(state.subscribers, username)
        let new_number_subs = state.number_of_subscribers - 1
        let new_state = types.SubredditState(..state, subscribers: new_subs, number_of_subscribers: new_number_subs)
        process.send(reply_to, Ok("Unsubscribed from subreddit "<> state.name))
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
    types.SubredditCreatePost(post_id, reply_to)->{
      let post = set.contains(state.posts, post_id)
      case post{
        True->{
          reply_to |> process.send(Error("Post "<> post_id <>" already exists in subreddit "<> state.name))
        }
        False->{
          reply_to |> process.send(Ok("Post "<> post_id <>" added to subreddit "<> state.name))
        }
      }

      let new_state = types.SubredditState(..state, posts: set.insert(state.posts, post_id))
      actor.continue(new_state)
    }
    types.SubredditPrintNumSubscribers()->{
      io.println("Subreddit "<> state.name <> " has " <> int.to_string(state.number_of_subscribers)<>" subscribers.")
      actor.continue(state)
    }
    types.SubredditGetLatestPosts(reply_to)->{
      let posts = state.posts
      process.send(reply_to, 
        Ok(json.to_string(json.array(
          set.to_list(posts), of: json.string
        )))
      )
      actor.continue(state)
    }
  }
}