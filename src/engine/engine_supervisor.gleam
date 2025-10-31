import gleam/otp/actor
import gleam/erlang/process.{type Subject}
import gleam/dict
import user/user_manager
import subreddit/subreddit_manager
import post/post_manager
import comment/comment_manager
import messaging/dm_manager
import types
import gleam/option.{None}

import engine/engine_receive



pub fn start() -> Result(Subject(types.EngineMessage), actor.StartError) {
    // Start all managers
    let dm_manager_state = types.DMManagerState(
        user_pairs: dict.new(),
        conversations: dict.new(),
        subjects: dict.new(),
    )
    let assert Ok(dm_manager_actor) = 
        actor.new(dm_manager_state)
        |> actor.on_message(dm_manager.dm_manager)
        |> actor.start()

    let comment_manager_state = types.CommentManagerState(
        comments: dict.new(),
        number_of_comments: 0,
        post_manager: None, // Placeholder, will update
        user_manager: None, // Placeholder
    )
    let assert Ok(comment_manager_actor) = 
        actor.new(comment_manager_state)
        |> actor.on_message(comment_manager.comment_manager)
        |> actor.start()

    let post_manager_state = types.PostManagerState(
        posts: dict.new(),
        number_of_posts: 0,
        comment_manager: comment_manager_actor.data,
        user_manager: None, // Placeholder
    )
    let assert Ok(post_manager_actor) = 
        actor.new(post_manager_state)
        |> actor.on_message(post_manager.post_manager)
        |> actor.start()

    let subreddit_manager_state = types.SubredditManagerState(
        subreddits: dict.new(),
        number_of_subreddits: 0,
        post_manager: post_manager_actor.data,
    )
    let assert Ok(subreddit_manager_actor) = 
        actor.new(subreddit_manager_state)
        |> actor.on_message(subreddit_manager.subreddit_manager)
        |> actor.start()

    let user_manager_state = types.UserManagerState(
        users: dict.new(),
        number_users: 0,
        subreddit_manager: subreddit_manager_actor.data,
        post_manager: post_manager_actor.data,
        comment_manager: comment_manager_actor.data,
        dm_manager: dm_manager_actor.data,
    )
    let assert Ok(user_manager_actor) = 
        actor.new(user_manager_state)
        |> actor.on_message(user_manager.user_manager)
        |> actor.start()

    // Update comment and post managers with user_manager
    process.send(comment_manager_actor.data, types.CommentManagerSetUserManager(user_manager_actor.data))
    process.send(comment_manager_actor.data, types.CommentManagerSetPostManager(post_manager_actor.data))
    process.send(post_manager_actor.data, types.PostManagerSetUserManager(user_manager_actor.data))

    let assert Ok(engine_receive_actor) = 
        actor.new(types.EngineReceiveState)
        |> actor.on_message(engine_receive.engine_receive_actor)
        |> actor.start()
    
    // Start engine supervisor
    let initial_state = types.EngineState(
        user_manager: user_manager_actor.data,
        subreddit_manager: subreddit_manager_actor.data,
        post_manager: post_manager_actor.data,
        comment_manager: comment_manager_actor.data,
        dm_manager: dm_manager_actor.data,
        engine_receive: engine_receive_actor.data,
    )

    case actor.new(initial_state)
    |> actor.on_message(engine_actor)
    |> actor.start() {
        Ok(started) -> Ok(started.data)
        Error(e) -> Error(e)
    }
}

//sends from here and receives from here
//build middleware tcp layer on top of this later

fn engine_actor(
    state: types.EngineState,
    message: types.EngineMessage,
) -> actor.Next(types.EngineState, types.EngineMessage) {
    case message {
        types.EngineGetUserManager(reply_with) -> {
            process.send(reply_with, state.user_manager)
            actor.continue(state)
        }
        types.EngineGetSubredditManager(reply_with) -> {
            process.send(reply_with, state.subreddit_manager)
            actor.continue(state)
        }
        types.EngineCreateUser(username) -> {
            process.send(state.user_manager, types.UserManagerCreateUser(username))
            actor.continue(state)
        }
        types.EngineUserCreateSubreddit(subreddit_name, description) -> {
            process.send(state.subreddit_manager, types.SubredditManagerCreateSubreddit(subreddit_name, description))
            actor.continue(state)
        }
        types.EngineUserJoinSubreddit(username, subreddit_name) -> {
            process.send(state.user_manager, types.UserManagerUserJoinSubreddit(username, subreddit_name))
            actor.continue(state)
        }
        types.EngineUserLeaveSubreddit(username, subreddit_name) -> {
            process.send(state.user_manager, types.UserManagerUserLeaveSubreddit(username, subreddit_name))
            actor.continue(state)
        }
        types.EngineUserCreatePost(username, subreddit_name, title, content) -> {
            process.send(state.user_manager, types.UserManagerUserCreatePost(username, subreddit_name, title, content))
            actor.continue(state)
        }
        types.EngineUserLikesPost(username, post_id) -> {
            process.send(state.post_manager, types.PostManagerUpvote(post_id, username))
            actor.continue(state)
        }
        types.EngineUserDislikesPost(username, post_id) -> {
            process.send(state.post_manager, types.PostManagerDownvote(post_id, username))
            actor.continue(state)
        }
        types.EngineUserCreateComment(username, post_id, parent_comment_id, content) -> {
            process.send(state.user_manager, types.UserManagerUserCreateComment(username, post_id, parent_comment_id, content))
            actor.continue(state)
        }
        types.EngineUserUpvotesComment(username, comment_id) -> {
            process.send(state.comment_manager, types.CommentManagerUpvoteComment(comment_id, username))
            actor.continue(state)
        }
        types.EngineUserDownvotesComment(username, comment_id) -> {
            process.send(state.comment_manager, types.CommentManagerDownvoteComment(comment_id, username))
            actor.continue(state)
        }
        types.EngineUserSendDM(username, other_username, content) -> {
            process.send(state.user_manager, types.UserManagerUserSendDM(username, other_username, content))
            actor.continue(state)
        }
        types.EngineGetAllComments()->{
            process.send(state.comment_manager, types.CommentManagerGetAllComments(state.engine_receive))
            actor.continue(state)
        }
        types.EngineGetAllPosts()->{
            process.send(state.post_manager, types.PostManagerGetAllPosts(state.engine_receive))
            actor.continue(state)
        }
        types.EngineGetAllUsers()->{
            process.send(state.user_manager, types.UserManagerGetAllUsers(state.engine_receive))
            actor.continue(state)
        }
        types.EngineGetAllSubreddits()->{
            process.send(state.subreddit_manager, types.SubredditManagerGetAllSubreddits(state.engine_receive))
            actor.continue(state)
        }
        types.EngineGetAllDMs()->{
            process.send(state.dm_manager, types.DMManagerGetAllDMs(state.engine_receive))
            actor.continue(state)
        }
        types.EngineGetUserFeed(username)->{
            process.send(state.user_manager, types.UserManagerGetUserFeed(username, state.engine_receive))
            actor.continue(state)
        }
        types.Shutdown -> {
            actor.stop()
        }
    }
}