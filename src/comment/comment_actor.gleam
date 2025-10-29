import types
import gleam/otp/actor
import gleam/erlang/process
import gleam/set


pub fn comment_actor(state: types.CommentState, message: types.CommentMessage) -> actor.Next(types.CommentState, types.CommentMessage) {
    case message {
        types.CommentUpvote(username, user_manager) -> {
            //see if already in downvotes, if so remove
            case set.contains(state.downvotes, username){
                True->{
                    let new_downvotes = set.delete(state.downvotes, username)
                    let new_upvotes = set.insert(state.upvotes, username)
                    process.send(user_manager, types.UserManagerUpdateKarma(username, 2))
                    let new_state = types.CommentState(
                        state.comment_id,
                        state.author_username,
                        state.content,
                        new_upvotes,
                        new_downvotes,
                        state.post,
                        state.parent,
                        state.replies,
                    )
                    actor.continue(new_state)
                }
                False->{
                    case set.contains(state.upvotes, username){
                        True->{
                            //already upvoted, do nothing
                            actor.continue(state)
                        }
                        False->{
                            let new_upvote = set.insert(state.upvotes, username)
                            process.send(user_manager, types.UserManagerUpdateKarma(username, 1))
                            let new_state = types.CommentState(
                                state.comment_id,
                                state.author_username,
                                state.content,
                                new_upvote,
                                state.downvotes,
                                state.post,
                                state.parent,
                                state.replies,
                            )
                            actor.continue(new_state)
                        }
                    }
                }
            }
        }
        types.CommentDownvote(username, user_manager) -> {
            //see if already in upvotes, if so remove
            case set.contains(state.upvotes, username){
                True->{
                    let new_upvotes = set.delete(state.upvotes, username)
                    let new_downvotes = set.insert(state.downvotes, username)
                    process.send(user_manager, types.UserManagerUpdateKarma(username, -2))
                    let new_state = types.CommentState( 
                        state.comment_id,
                        state.author_username,
                        state.content,
                        new_upvotes,
                        new_downvotes,
                        state.post,
                        state.parent,
                        state.replies,
                    )
                    actor.continue(new_state)
                }
                False->{
                    case set.contains(state.downvotes, username){
                        True->{
                            //already downvoted, do nothing
                            actor.continue(state)
                        }
                        False->{
                            let new_downvote = set.insert(state.downvotes, username)
                            process.send(user_manager, types.UserManagerUpdateKarma(username, -1))
                            let new_state = types.CommentState(
                                state.comment_id,
                                state.author_username,
                                state.content,
                                state.upvotes,
                                new_downvote,
                                state.post,
                                state.parent,
                                state.replies,
                            )
                            actor.continue(new_state)
                        }
                    }
                }
            }
        }
        types.CommentAddReply(reply_comment_id) -> {
            let new_replies = set.insert(state.replies, reply_comment_id)
            let new_state = types.CommentState(
                state.comment_id,
                state.author_username,
                state.content,
                state.upvotes,
                state.downvotes,
                state.post,
                state.parent,
                new_replies,
            )
            actor.continue(new_state)
        }
        types.CommentGetAll(username, reply_to) -> {
            //send all info about comment to reply_to
            process.send(reply_to, types.EngineReceiveCommentData(
                username, 
                state.comment_id,
                state.author_username,
                state.content,
                set.size(state.upvotes),
                set.size(state.downvotes),
                state.post,
                state.parent,
                state.replies,
            ))
            actor.continue(state)
        }
        _ -> {
        actor.continue(state)
        }
    }
}