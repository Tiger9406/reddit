import types
import gleam/otp/actor
import gleam/erlang/process
import gleam/set
import gleam/json


pub fn post_actor(state: types.PostState, message: types.PostMessage) -> actor.Next(types.PostState, types.PostMessage) {
  case message {
    types.PostUpvote(username, user_manager, reply_to) -> {
        //see if already in downvotes, if so remove
        case set.contains(state.downvotes, username){
            True->{
                let new_downvotes = set.delete(state.downvotes, username)
                let new_upvotes = set.insert(state.upvotes, username)
                process.send(user_manager, types.UserManagerUpdateKarma(username, 2))
                process.send(reply_to, Ok("Upvoted successfully"))
                let new_state = types.PostState(
                    state.post_id,
                    state.author_username,
                    state.subreddit_name,
                    state.title,
                    state.content,
                    new_upvotes,
                    new_downvotes,
                    state.comments,
                )
                actor.continue(new_state)
            }
            False->{
                case set.contains(state.upvotes, username){
                    True->{
                        process.send(reply_to, Ok("Already upvoted; successful"))
                        actor.continue(state)
                    }
                    False->{
                        let new_upvote = set.insert(state.upvotes, username)
                        process.send(user_manager, types.UserManagerUpdateKarma(username, 1))
                        process.send(reply_to, Ok("Upvoted successfully"))
                        let new_state = types.PostState(
                            state.post_id,
                            state.author_username,
                            state.subreddit_name,
                            state.title,
                            state.content,
                            new_upvote,
                            state.downvotes,
                            state.comments,
                        )
                        actor.continue(new_state)
                    }
                }
            }
        }
    }
    types.PostDownvote(username, user_manager, reply_to) -> {
        //see if already in upvotes, if so remove
        case set.contains(state.upvotes, username){
            True->{
                let new_upvotes = set.delete(state.upvotes, username)
                let new_downvotes = set.insert(state.downvotes, username)
                process.send(user_manager, types.UserManagerUpdateKarma(username, -2))
                process.send(reply_to, Ok("Downvoted successfully"))
                let new_state = types.PostState(
                    state.post_id,
                    state.author_username,
                    state.subreddit_name,
                    state.title,
                    state.content,
                    new_upvotes,
                    new_downvotes,
                    state.comments,
                )
                actor.continue(new_state)
            }
            False->{
                case set.contains(state.downvotes, username){
                    True->{
                        process.send(reply_to, Ok("Already downvoted; successful"))
                        //already downvoted, do nothing
                        actor.continue(state)
                    }
                    False->{
                        let new_downvote = set.insert(state.downvotes, username)
                        process.send(user_manager, types.UserManagerUpdateKarma(username, -1))
                        process.send(reply_to, Ok("Downvoted successfully"))
                        let new_state = types.PostState(
                            state.post_id,
                            state.author_username,
                            state.subreddit_name,
                            state.title,
                            state.content,
                            state.upvotes,
                            new_downvote,
                            state.comments,
                        )
                        actor.continue(new_state)
                    }
                }
            }
        }
    }
    types.PostAddComment(comment_id, reply_to) -> {
        let new_comments = set.insert(state.comments, comment_id)
        let new_state = types.PostState(
            state.post_id,
            state.author_username,
            state.subreddit_name,
            state.title,
            state.content,
            state.upvotes,
            state.downvotes,
            new_comments,
        )
        process.send(reply_to, Ok("Comment added to post successfully"))
        actor.continue(new_state)
    }
    types.PostGetAll(reply_to) -> {
        //send everything about this post to Subject(Result(String, String))
        process.send(reply_to, 
            Ok(json.to_string(json.object([
                #("post_id", json.string(state.post_id)),
                #("author_username", json.string(state.author_username)),
                #("subreddit_name", json.string(state.subreddit_name)),
                #("title", json.string(state.title)),
                #("content", json.string(state.content)),
                #("upvotes", json.int(set.size(state.upvotes))),
                #("downvotes", json.int(set.size(state.downvotes))),
                #("comments", 
                    json.array(
                        set.to_list(state.comments)
                        , of: json.string
                    )
                ),]
            ))
        ))
        actor.continue(state)
    }
    
    _ -> {
      actor.continue(state)
    }
  }
}