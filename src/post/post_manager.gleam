import types
import gleam/otp/actor
import gleam/dict
import gleam/erlang/process
import gleam/int
import gleam/set
import post/post_actor.{post_actor}
import gleam/io
import gleam/option.{Some, None}

pub fn post_manager(state: types.PostManagerState, message: types.PostManagerMessage) -> actor.Next(types.PostManagerState, types.PostManagerMessage) {
    case message {
        types.PostManagerGetPost(post_id, reply_with, username) -> {
            case dict.get(state.posts, post_id){
                Ok(post_actor)->process.send(post_actor, types.PostGetAll(username, reply_with))
                Error(_)->Nil
            }
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
            case dict.get(state.posts, post_id){
                Ok(post_actor)->{
                    case state.user_manager {
                        Some(user_manager) -> process.send(post_actor, types.PostUpvote(username, user_manager))
                        None -> io.println("User manager not set in post manager")
                    }
                }
                Error(_)->Nil
            }            
            actor.continue(state)
        }
        types.PostManagerDownvote(post_id, username) -> {
            //send message to post actor to downvote
            case dict.get(state.posts, post_id){
                Ok(post_actor)->{
                    case state.user_manager {
                        Some(user_manager) -> process.send(post_actor, types.PostDownvote(username, user_manager))
                        None -> io.println("User manager not set in post manager")
                    }
                }
                Error(_)->Nil
            }   
            
            actor.continue(state)
        }
        types.PostManagerAddCommentToPost(post_id, comment_id) -> {
            //send message to post actor to add comment
            case dict.get(state.posts, post_id){
                Ok(post_actor)->process.send(post_actor, types.PostAddComment(comment_id))
                Error(_)->Nil
            }
            actor.continue(state)
        }
        types.PostManagerSetUserManager(user_manager_given)->{
            let new_state = types.PostManagerState(..state, user_manager: Some(user_manager_given))
            actor.continue(new_state)
        }
        types.PostManagerGetAllPosts(reply_to)->{
            process.send(reply_to, types.EngineReceiveAllPosts(state))
            io.println("sending to engine post stats")
            actor.continue(state)
        }
    }
}