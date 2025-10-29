
import gleam/io
import gleam/otp/actor
import types


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
    }
}