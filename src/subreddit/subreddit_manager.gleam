
import types
import gleam/otp/actor
import gleam/set
import gleam/dict
import gleam/erlang/process
import gleam/io

import subreddit/subreddit_actor.{subreddit_actor}


pub fn subreddit_manager(state: types.SubredditManagerState, message: types.SubredditManagerMessage) -> actor.Next(types.SubredditManagerState, types.SubredditManagerMessage) {
  case message {
    //handle messages here
    types.SubredditManagerCreateSubreddit(name, description) -> {
        //create subreddit actor
        let initial_state = types.SubredditState(
            name,
            description,
            set.new(),
            set.new(),
            0,
            0,
        )
        let assert Ok(actor) = actor.new(initial_state) |> actor.on_message(subreddit_actor) |> actor.start()
        let subject = actor.data
        let new_subreddits = dict.insert(state.subreddits, name, subject)
        let new_state = types.SubredditManagerState(
            new_subreddits,
            state.number_of_subreddits + 1,
            state.post_manager,
        )
        actor.continue(new_state)
    }
    types.SubredditManagerGetSubreddit(name, reply_to, username) -> {
        //lookup subreddit in dict and reply with everything about it
        case dict.get(state.subreddits, name) {
            Ok(subreddit_actor) -> {
                process.send(subreddit_actor, types.SubredditGetAll(username, reply_to))
            }
            Error(_) -> {
                io.println("Subreddit not found")
            }
        }
        actor.continue(state)
    }
    types.SubredditManagerAddSubscriberToSubreddit(subreddit_name, username, user_actor) -> {
        //send message to subreddit actor to add subscriber
        let assert Ok(subreddit_actor) = dict.get(state.subreddits, subreddit_name)
        process.send(subreddit_actor, types.SubredditAddSubscriber(username, user_actor))
        actor.continue(state)
    }
    types.SubredditManagerRemoveSubscriberFromSubreddit(subreddit_name, username, user_actor) -> {
        //send message to subreddit actor to remove subscriber
        let assert Ok(subreddit_actor) = dict.get(state.subreddits, subreddit_name)
        process.send(subreddit_actor, types.SubredditRemoveSubscriber(username, user_actor))
        actor.continue(state)
    }
    types.SubredditManagerCreatedPostInSubreddit(subreddit_name, post_id) -> {
        //send message to subreddit actor to add post
        let assert Ok(subreddit_actor) = dict.get(state.subreddits, subreddit_name)
        process.send(subreddit_actor, types.SubredditCreatePost(post_id))
        actor.continue(state)
    }
  }
}