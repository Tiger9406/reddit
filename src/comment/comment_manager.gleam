
import gleam/io
import types
import gleam/otp/actor
import gleam/erlang/process
import gleam/set
import gleam/int
import gleam/dict
import gleam/option.{Some, None}

import comment/comment_actor.{comment_actor}

pub fn comment_manager(state: types.CommentManagerState, message: types.CommentManagerMessage) -> actor.Next(types.CommentManagerState, types.CommentManagerMessage) {
  case message {
    types.CommentManagerCreateComment(username, post_id, content, parent, user_actor, reply_to) -> {
        //create comment actor
        let new_number_comments = state.number_of_comments + 1
        let comment_id = new_number_comments
        let string_id = int.to_string(comment_id)

        let initial_state = types.CommentState(
            string_id,
            username,
            content,
            set.new(),
            set.new(),
            post_id,
            parent,
            set.new(),
        )
        let assert Ok(actor) = actor.new(initial_state) |> actor.on_message(comment_actor) |> actor.start()
        let subject = actor.data
        let new_comments = dict.insert(state.comments, string_id, subject)
        let new_number_comments = state.number_of_comments + 1
        process.send(user_actor, types.UserCommentCreated(string_id))

        case state.post_manager {
            Some(post_manager) -> {
                process.send(post_manager, types.PostManagerAddCommentToPost(post_id, string_id, reply_to))
                case parent{
                    Some(parent) -> {
                        //send message to parent comment to add reply
                        let assert Ok(parent_comment_actor) = dict.get(state.comments, parent)
                        process.send(parent_comment_actor, types.CommentAddReply(string_id))
                    }
                    None -> {
                        Nil
                    }
                }
            }
            None -> {
                io.println("Post manager not set in comment manager")
            }
        }
        
        let new_state = types.CommentManagerState(
            new_comments,
            new_number_comments,
            state.post_manager,
            state.user_manager,
        )
        actor.continue(new_state)
    }
    types.CommentManagerGetComment(comment_id, reply_to, username) -> {
        case dict.get(state.comments, comment_id) {
            Ok(comment_actor) -> {
                process.send(comment_actor, types.CommentGetAll(username, reply_to))
            }
            Error(_) -> {
                io.println("Comment not found")
            }
        }
        actor.continue(state)
    }
    types.CommentManagerUpvoteComment(comment_id, username, reply_to) -> {
        //send message to comment actor to upvote
        case dict.get(state.comments, comment_id) {
            Ok(comment_actor) -> {
                case state.user_manager {
                    Some(user_manager) -> {
                        process.send(comment_actor, types.CommentUpvote(username, user_manager))
                        process.send(reply_to, Ok("Comment upvote sent"))
                    }
                    None -> {
                        io.println("User manager not set in comment manager")
                    }
                }
            }
            Error(_) -> {
                io.println("Comment not found")
            }
        }
        
        actor.continue(state)
    }
    types.CommentManagerDownvoteComment(comment_id, username, reply_to) -> {
        //send message to comment actor to downvote
        case dict.get(state.comments, comment_id) {
            Ok(comment_actor) -> {
                case state.user_manager {
                    Some(user_manager) -> {
                        process.send(comment_actor, types.CommentDownvote(username, user_manager))
                        process.send(reply_to, Ok("Comment downvote sent"))
                    }
                    None -> {
                        io.println("User manager not set in comment manager")
                    }
                }
            }
            Error(_) -> {
                io.println("Comment not found")
            }
        }
        actor.continue(state)
    }
    types.CommentManagerSetUserManager(user_manager) -> {
        let new_state = types.CommentManagerState(
            state.comments,
            state.number_of_comments,
            state.post_manager,
            Some(user_manager),
        )
        actor.continue(new_state)
    }
    types.CommentManagerSetPostManager(post_manager) -> {
        let new_state = types.CommentManagerState(
            state.comments,
            state.number_of_comments,
            Some(post_manager),
            state.user_manager,
        )
        actor.continue(new_state)
    }
    types.CommentManagerGetAllComments(_reply_to)->{
        //obsolete now
        actor.continue(state)
    }
  }
}