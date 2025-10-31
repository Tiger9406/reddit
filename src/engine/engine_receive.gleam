
import gleam/io
import gleam/otp/actor
import types
import gleam/int
import gleam/dict
import gleam/erlang/process

pub fn engine_receive_actor(
    state: types.EngineReceiveState,
    message: types.EngineReceiveMessage,
) -> actor.Next(types.EngineReceiveState, types.EngineReceiveMessage) {
    case message {
        //handle messages here
        types.EngineReceiveUser(username, user_state)->{
            io.println(username <> "info received: " <>user_state.username)
            actor.continue(state)
        }
        types.EngineReceiveDMMessages(from_username, messages) -> {
            io.println("DMs with " <> from_username <> ":" <> messages.conversation_id)
            actor.continue(state)
        }
        types.EngineReceiveSubredditDetails(username, subreddit) -> {
            io.println("Subscribed Subreddits for " <> username <> ":" <> subreddit.name)
            actor.continue(state)
        }
        types.EngineReceiveCommentData(username, comment_state) -> {
            io.print(username<> " comment state: " <> comment_state.comment_id)
            actor.continue(state)
        }
        types.EngineReceivePostDetails(username, post_state)->{
            io.println(username<>" post state: " <> post_state.post_id)
            actor.continue(state)
        }
        types.EngineReceiveAllComments(comment_manager_state)->{
            io.println("Received all of comment manager; number of comments: ")
            io.println(int.to_string(comment_manager_state.number_of_comments))
            actor.continue(state)
        }
        types.EngineReceiveAllDMs(dm_manager_state)->{
            io.println("Received all of dm manager; number of dms: ")
            io.println(int.to_string(dict.size(dm_manager_state.conversations)))
            actor.continue(state)
        }
        types.EngineReceiveAllPosts(post_manager_state)->{
            io.println("Received all of post manager; number of posts:")
            io.println(int.to_string(post_manager_state.number_of_posts))
            actor.continue(state)
        }
        types.EngineReceiveAllSubreddits(subreddit_manager_state)->{
            io.println("Received all of subreddit manager; number of subreddits:")
            io.println(int.to_string(subreddit_manager_state.number_of_subreddits))
            dict.each(subreddit_manager_state.subreddits, fn(_, v) {
                process.send(v, types.SubredditPrintNumSubscribers)
            })
            actor.continue(state)
        }
        types.EngineReceiveAllUsers(user_manager_state)->{
            io.println("Received all of user manager; number of users:")
            io.println(int.to_string(user_manager_state.number_users))
            actor.continue(state)
        }
    }
}