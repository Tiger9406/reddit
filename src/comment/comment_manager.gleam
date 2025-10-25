
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
    types.CommentManagerCreateComment(username, post_id, content, parent, user_actor) -> {
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
        process.send(state.post_manager, types.PostManagerAddCommentToPost(post_id, string_id))
        case parent{
            Some(parent) -> {
                //send message to parent comment to add reply
                let assert Ok(parent_comment_actor) = dict.get(state.comments, parent)
                process.send(parent_comment_actor, types.CommentAddReply(string_id))
            }
            None -> {
                //do nothing
                Nil
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
    types.CommentManagerGetComment(comment_id, reply_with) -> {
        //lookup comment in dict and reply with subject
        actor.continue(state)
    }
    types.CommentManagerUpvoteComment(comment_id, username) -> {
        //send message to comment actor to upvote
        let assert Ok(comment_actor) = dict.get(state.comments, comment_id)
        process.send(comment_actor, types.CommentUpvote(username, state.user_manager))
        actor.continue(state)
    }
    types.CommentManagerDownvoteComment(comment_id, username) -> {
        //send message to comment actor to downvote
        let assert Ok(comment_actor) = dict.get(state.comments, comment_id)
        process.send(comment_actor, types.CommentDownvote(username, state.user_manager))
        actor.continue(state)
    }

    _ -> {
      actor.continue(state)
    }
  }
}