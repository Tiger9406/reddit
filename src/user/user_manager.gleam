import gleam/otp/actor
import gleam/erlang/process
import user/user_actor.{user_actor}
import gleam/set
import gleam/dict

import types.{type UserManagerState, type UserManagerMessage}

pub fn user_manager(state: UserManagerState, message: UserManagerMessage) -> actor.Next(UserManagerState, UserManagerMessage) {
  case message {
    types.UserManagerCreateUser(username, reply_with) -> {
        //create user actor
        let initial_state = types.UserState(
            username,
            0,
            set.new(),
            set.new(),
            set.new(),
            set.new(),
        )
        let assert Ok(actor) = actor.new(initial_state) |> actor.on_message(user_actor) |> actor.start()
        let subject = actor.data
        let new_users = dict.insert(state.users, username, subject)
        let new_number_users = state.number_users + 1
        let new_state = types.UserManagerState(
            new_users,
            new_number_users,
            state.subreddit_manager,
            state.post_manager,
            state.comment_manager,
            state.dm_manager,
        )
        actor.continue(new_state)
    }
    types.UserManagerGetNumberUsers(reply_to) -> {
        //reply to whoever sent get number users? how to get sender?
        actor.continue(state)
    }
    types.UserManagerGetUser(username, reply_with) -> {
        //lookup user in dict and reply with subject
        actor.continue(state)
    }
    types.UserManagerUserJoinSubreddit(username, subreddit_name) -> {
        let assert Ok(actor) = dict.get(state.users, username)
        process.send(state.subreddit_manager, types.SubredditManagerAddSubscriberToSubreddit(subreddit_name, username, actor))
        actor.continue(state)
    }

    types.UserManagerUserLeaveSubreddit(username, subreddit_name) -> {
        let assert Ok(actor) = dict.get(state.users, username)
        process.send(state.subreddit_manager, types.SubredditManagerRemoveSubscriberFromSubreddit(subreddit_name, username, actor))
        actor.continue(state)
    }
    types.UserManagerUserCreatePost(username, subreddit_name, title, content) -> {
        let assert Ok(actor) = dict.get(state.users, username)
        process.send(state.post_manager, types.PostManagerCreatePost(username, subreddit_name, title, content, actor))
        actor.continue(state)
    }
    types.UserManagerUserCreateComment(username, post_id, comment_id, content) -> {
        let assert Ok(actor) = dict.get(state.users, username)
        process.send(state.comment_manager, types.CommentManagerCreateComment(username, post_id, content, comment_id, actor))
        actor.continue(state)
    }
    types.UserManagerUserUpvotePost(username, post_id) -> {
        let assert Ok(actor) = dict.get(state.users, username)
        process.send(state.post_manager, types.PostManagerUpvote(username, post_id))
        actor.continue(state)
    }
    types.UserManagerUserDownvotePost(username, post_id) -> {
        let assert Ok(actor) = dict.get(state.users, username)
        process.send(state.post_manager, types.PostManagerDownvote(username, post_id))
        actor.continue(state)
    }
    types.UserManagerUserSendDM(username, other_username, content) -> {
        let assert Ok(actor) = dict.get(state.users, username)
        let assert Ok(other_actor) = dict.get(state.users, other_username)
        process.send(state.dm_manager, types.SendDM(username, other_username, content, actor, other_actor))
        actor.continue(state)
    }
    _ -> {
      //other messages to be handled later
      actor.continue(state)
    }
  }
}