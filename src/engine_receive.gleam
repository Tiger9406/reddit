
import gleam/io
import gleam/otp/actor
import types
import gleam/int


pub fn engine_receive_actor(
    state: types.EngineReceiveState,
    message: types.EngineReceiveMessage,
) -> actor.Next(types.EngineReceiveState, types.EngineReceiveMessage) {
    case message {
        //handle messages here
        types.EngineReceiveKarma(username, karma) -> {
            io.println("User " <> username <> " has karma: " <> int.to_string(karma))
            actor.continue(state)
        }
        types.EngineReceiveDMConversations(username, conversations) -> {
            io.println("DM Conversations:")
            actor.continue(state)
        }
        types.EngineReceiveDMMessages(from_username, messages) -> {
            io.println("DMs with " <> from_username <> ":")
            actor.continue(state)
        }
        types.EngineReceiveSubscribedSubreddits(username, subreddits) -> {
            io.println("Subscribed Subreddits for " <> username <> ":")
            actor.continue(state)
        }
        types.EngineReceiveCommentData(username, comment_id, author_username, content, upvotes, downvotes, post_id, parent, replies, ) -> {
            io.println("Comment ID: " <> comment_id)
            io.println("Author: " <> author_username)
            io.println("Content: " <> content)
            io.println("Upvotes: " <> int.to_string(upvotes))
            io.println("Downvotes: " <> int.to_string(downvotes))
            io.println("Post ID: " <> post_id)
            actor.continue(state)
        }
        _ -> {
            actor.continue(state)
        }
    }
}