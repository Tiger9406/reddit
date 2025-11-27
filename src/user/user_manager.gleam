import gleam/otp/actor
import gleam/erlang/process
import user/user_actor.{user_actor}
import gleam/set
import gleam/dict
import gleam/io

import types.{type UserManagerState, type UserManagerMessage}

pub fn user_manager(state: UserManagerState, message: UserManagerMessage) -> actor.Next(UserManagerState, UserManagerMessage) {
  case message {
    types.UserManagerCreateUser(username, reply_to) -> {
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
        let new_state = types.UserManagerState(..state, users: new_users, number_users: new_number_users)
        process.send(reply_to, Ok("User created successfully"))
        actor.continue(new_state)
    }
    types.UserManagerGetUser(username, reply_with) -> {
        case dict.get(state.users, username){
            Ok(actor)->process.send(actor, types.UserGetAll(username, reply_with))
            Error(_)->process.send(reply_with, Error("User not found"))
        }
        actor.continue(state)
    }
    types.UserManagerUserJoinSubreddit(username, subreddit_name, reply_to) -> {
        case dict.get(state.users, username){
            Ok(actor)->process.send(state.subreddit_manager, types.SubredditManagerAddSubscriberToSubreddit(subreddit_name, username, actor, reply_to))
            Error(_)->process.send(reply_to, Error("User not found"))
        }
        actor.continue(state)
    }

    types.UserManagerUserLeaveSubreddit(username, subreddit_name, reply_to) -> {
        case dict.get(state.users, username){
            Ok(actor)->process.send(state.subreddit_manager, types.SubredditManagerRemoveSubscriberFromSubreddit(subreddit_name, username, actor, reply_to))
            Error(_)->process.send(reply_to, Error("User not found"))
        }
        
        actor.continue(state)
    }
    types.UserManagerUserCreatePost(username, subreddit_name, title, content, reply_to) -> {
        case dict.get(state.users, username){
            Ok(actor)->process.send(state.post_manager, types.PostManagerCreatePost(username, subreddit_name, state.subreddit_manager, title, content, actor, reply_to))

            Error(_)->process.send(reply_to, Error("User not found"))
        }
        
        actor.continue(state)
    }
    types.UserManagerUserCreateComment(username, post_id, comment_id, content, reply_to) -> {
        case dict.get(state.users, username){
            Ok(actor)->process.send(state.comment_manager, types.CommentManagerCreateComment(username, post_id, content, comment_id, actor, reply_to))
            Error(_)->process.send(reply_to, Error("User not found"))
        }
        
        actor.continue(state)
    }
    types.UserManagerUserUpvotePost(username, post_id, reply_to) -> {
        case dict.get(state.users, username){
            Ok(_)->process.send(state.post_manager, types.PostManagerUpvote(username, post_id, reply_to))
            Error(_)->process.send(reply_to, Error("User not found"))
        }
        actor.continue(state)
    }
    types.UserManagerUserDownvotePost(username, post_id, reply_to) -> {
        case dict.get(state.users, username){
            Ok(_)->process.send(state.post_manager, types.PostManagerDownvote(username, post_id, reply_to))
            Error(_)->process.send(reply_to, Error("User not found"))
        }
        actor.continue(state)
    }
    types.UserManagerUserSendDM(username, other_username, content, reply_to) -> {
        case dict.get(state.users, username) {
            Ok(_)->{
                case dict.get(state.users, other_username){
                    Ok(_)->process.send(state.dm_manager, types.SendDM(username, other_username, content, reply_to))
                    Error(_)-> process.send(reply_to, Error("User not found"))
                }
            }
            Error(_)->process.send(reply_to, Error("User not found"))
        }
        actor.continue(state)
    }
    types.UserManagerGetUserFeed(username, reply_to)->{
        //get most recent posts from following subreddits
        //ig get all following subreddits & then get recent posts? idk
        //send to user to send to each of its following subreddits to send to reply_to username & postid?
        case dict.get(state.users, username){
            Ok(actor)->{
                process.send(actor, types.UserGetFeed(reply_to, state.subreddit_manager))
            }
            Error(_)-> process.send(reply_to, Error("User not found"))
        }
        actor.continue(state)
    }
    types.UserManagerUpdateKarma(username, delta)->{
        case dict.get(state.users, username) {
            Ok(actor)->{
                process.send(actor, types.UserUpdateKarma(delta))
            }
            Error(_)->io.println("can't find username in update karma")
        }
        actor.continue(state)
    }
  }
}