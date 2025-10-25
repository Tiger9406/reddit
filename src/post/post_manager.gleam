import types
import gleam/otp/actor
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/set
import post/post_actor.{post_actor}

pub fn post_manager(state: types.PostManagerState, message: types.PostManagerMessage) -> actor.Next(types.PostManagerState, types.PostManagerMessage) {
    case message {
        types.PostManagerInitialize() -> {
            actor.continue(state)
        }
        types.PostManagerGetPost(post_id, reply_with) -> {
            //lookup post in dict and reply with subject
            actor.continue(state)
        }
        types.PostManagerCreatePost(author_username, subreddit_name, title, content, user_actor) -> {
            let new_post_id = state.number_of_posts + 1 //simple way to generate post ids
            let string_id = int.to_string(new_post_id)
            //create post actor
            let initial_state = types.PostState(
                string_id,
                author_username,
                subreddit_name,
                title,
                content,
                set.new(),
                set.new(),
                set.new(),
            )
            let assert Ok(actor) = actor.new(initial_state) |> actor.on_message(post_actor) |> actor.start()
            let subject = actor.data
            process.send(user_actor, types.UserPostCreated(string_id))
            let new_posts = dict.insert(state.posts, string_id, subject)
            let new_state = types.PostManagerState(
                new_posts,
                state.number_of_posts + 1,
                state.comment_manager,
                state.user_manager,
            )
            actor.continue(new_state)
        }
        types.PostManagerUpvote(post_id, username) -> {
            //send message to post actor to upvote
            let assert Ok(post_actor) = dict.get(state.posts, post_id)
            process.send(post_actor, types.PostUpvote(username, state.user_manager))
            actor.continue(state)
        }
        types.PostManagerDownvote(post_id, username) -> {
            //send message to post actor to downvote
            let assert Ok(post_actor) = dict.get(state.posts, post_id)
            process.send(post_actor, types.PostDownvote(username, state.user_manager))
            actor.continue(state)
        }
        types.PostManagerAddCommentToPost(post_id, comment_id) -> {
            //send message to post actor to add comment
            let assert Ok(post_actor) = dict.get(state.posts, post_id)
            process.send(post_actor, types.PostAddComment(comment_id))
            actor.continue(state)
        }
        _ -> {
            actor.continue(state)
        }
    }
}