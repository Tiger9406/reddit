import types
import gleam/otp/actor
import gleam/erlang/process
import gleam/set


pub fn post_actor(state: types.PostState, message: types.PostMessage) -> actor.Next(types.PostState, types.PostMessage) {
  case message {
    types.PostUpvote(username, user_manager) -> {
        //see if already in downvotes, if so remove
        case set.contains(state.downvotes, username){
            True->{
                let new_downvotes = set.delete(state.downvotes, username)
                let new_upvotes = set.insert(state.upvotes, username)
                process.send(user_manager, types.UserManagerUpdateKarma(username, 2))
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
                        //already upvoted, do nothing
                        actor.continue(state)
                    }
                    False->{
                        let new_upvote = set.insert(state.upvotes, username)
                        process.send(user_manager, types.UserManagerUpdateKarma(username, 1))
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
    types.PostDownvote(username, user_manager) -> {
        //see if already in upvotes, if so remove
        case set.contains(state.upvotes, username){
            True->{
                let new_upvotes = set.delete(state.upvotes, username)
                let new_downvotes = set.insert(state.downvotes, username)
                process.send(user_manager, types.UserManagerUpdateKarma(username, -2))
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
                        //already downvoted, do nothing
                        actor.continue(state)
                    }
                    False->{
                        let new_downvote = set.insert(state.downvotes, username)
                        process.send(user_manager, types.UserManagerUpdateKarma(username, -1))
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
    types.PostGetScore(reply_with) -> {
        //reply to whoever
        actor.continue(state)
    }
    types.PostAddComment(comment_id) -> {
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
        actor.continue(new_state)
    }
    
    _ -> {
      actor.continue(state)
    }
  }
}