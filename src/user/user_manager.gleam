import gleam/otp/actor
import gleam/erlang/process
import user/user_actor.{user_actor}
import gleam/set
import gleam/dict
import gleam/io

import types.{type UserManagerState, type UserManagerMessage}

pub fn user_manager(state: UserManagerState, message: UserManagerMessage) -> actor.Next(UserManagerState, UserManagerMessage) {
  case message {
    types.UserManagerCreateUser(username) -> {
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
    types.UserManagerGetUser(username, reply_with) -> {
        case dict.get(state.users, username){
            Ok(actor)->{
                process.send(actor, types.UserGetAll(username, reply_with))
            }
            Error(_)->{
                io.println("actor not found")
            }
        }
        actor.continue(state)
    }
    types.UserManagerUserJoinSubreddit(username, subreddit_name) -> {
        case dict.get(state.users, username){
            Ok(actor)->{
                process.send(state.subreddit_manager, types.SubredditManagerAddSubscriberToSubreddit(subreddit_name, username, actor))
            }
            Error(_)->{
                io.println("actor not found")
            }
        }
        actor.continue(state)
    }

    types.UserManagerUserLeaveSubreddit(username, subreddit_name) -> {
        case dict.get(state.users, username){
            Ok(actor)->{
                process.send(state.subreddit_manager, types.SubredditManagerRemoveSubscriberFromSubreddit(subreddit_name, username, actor))
            }
            Error(_)->{
                io.println("actor not found")
            }
        }
        
        actor.continue(state)
    }
    types.UserManagerUserCreatePost(username, subreddit_name, title, content) -> {
        case dict.get(state.users, username){
            Ok(actor)->{
                process.send(state.post_manager, types.PostManagerCreatePost(username, subreddit_name, title, content, actor))
            }
            Error(_)->{
                io.println("actor not found")
            }
        }
        
        actor.continue(state)
    }
    types.UserManagerUserCreateComment(username, post_id, comment_id, content) -> {
        case dict.get(state.users, username){
            Ok(actor)->{
                process.send(state.comment_manager, types.CommentManagerCreateComment(username, post_id, content, comment_id, actor))
            }
            Error(_)->{
                io.println("actor not found")
            }
        }
        
        actor.continue(state)
    }
    types.UserManagerUserUpvotePost(username, post_id) -> {
        case dict.get(state.users, username){
            Ok(_)->{
                process.send(state.post_manager, types.PostManagerUpvote(username, post_id))
            }
            Error(_)->{
                io.println("actor not found")
            }
        }
        actor.continue(state)
    }
    types.UserManagerUserDownvotePost(username, post_id) -> {
        case dict.get(state.users, username){
            Ok(_)->{
                process.send(state.post_manager, types.PostManagerDownvote(username, post_id))
            }
            Error(_)->{
                io.println("actor not found")
            }
        }
        actor.continue(state)
    }
    types.UserManagerUserSendDM(username, other_username, content) -> {
        case dict.get(state.users, username) {
            Ok(_)->{
                case dict.get(state.users, other_username){
                    Ok(_)->process.send(state.dm_manager, types.SendDM(username, other_username, content))
                    Error(_)-> io.println("can't find other username")
                }
            }
            Error(_)->io.println("can't find username")
        }
        actor.continue(state)
    }
    _ -> {
      //other messages to be handled later
      actor.continue(state)
    }
  }
}