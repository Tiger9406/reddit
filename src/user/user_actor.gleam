import gleam/otp/actor
import types.{type UserMessage, type UserState}
import gleam/set
import gleam/erlang/process
import gleam/list
import gleam/json
import gleam/result

pub fn user_actor(state: UserState, message: UserMessage) -> actor.Next(UserState, UserMessage) {
  case message {
    types.UserUpdateKarma(delta) -> {
      let new_karma = state.karma + delta
      let new_state = types.UserState(..state, karma: new_karma)
      actor.continue(new_state)
    }

    types.UserGetAll(_username, reply_to)->{
      process.send(reply_to, Ok(json.to_string(json.object([
        #("username", json.string(state.username)),
        #("karma", json.int(state.karma)),
        #("subscribed_subreddits", json.int(set.size(state.subscribed_subreddits))),
        #("created_posts", json.int(set.size(state.created_posts))),
        #("created_comments", json.int(set.size(state.created_comments))),
      ]))))
      actor.continue(state)
    }

    types.UserJoinedSubreddit(subreddit_name) ->{
      let new_subs = set.insert(state.subscribed_subreddits, subreddit_name)
      let new_state = types.UserState(..state, subscribed_subreddits: new_subs)
      actor.continue(new_state)
    }
    types.UserLeftSubreddit(subreddit_name) ->{
        let new_subs = set.delete(state.subscribed_subreddits, subreddit_name)
        let new_state = types.UserState(..state, subscribed_subreddits: new_subs)
        actor.continue(new_state)
    }
    types.UserPostCreated(post_id) -> {
        let new_posts = set.insert(state.created_posts, post_id)
        let new_state = types.UserState(..state, created_posts: new_posts)
        actor.continue(new_state)
    }
    types.UserCommentCreated(comment_id) -> {
        let new_comments = set.insert(state.created_comments, comment_id)
        let new_state = types.UserState(..state, created_comments: new_comments)
        actor.continue(new_state)
    }
    types.UserGetFeed(reply_to, subreddit_manager)->{
      let subreddits = set.to_list(state.subscribed_subreddits)

      let all_post_ids =
        list.map(subreddits, fn(sub_name) {
          let call_result =
            process.call(
              subreddit_manager,
              100,
              fn(response_subject) {
                types.SubredditManagerGetLatestPosts(sub_name, response_subject)
              },
            )

          result.unwrap(call_result, [])
        })
        |> list.flatten()

      // 5. Send final response to API
      process.send(reply_to, Ok(all_post_ids))
      actor.continue(state)
    }
  }
}