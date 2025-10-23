import gleam/otp/actor
import user/user_types.{type UserMessage, type UserState}
import gleam/set as set


fn handle_message(state: UserState, message: UserMessage) -> actor.Next(UserState, UserMessage) {
  case message {
    user_types.Initialize(username, subreddit_supervisor, dm_supervisor) ->{
      let new_state = user_types.UserState(
        username,
        0,
        set.new(),
        set.new(),
        set.new(),
        set.new(),
        subreddit_supervisor,
        dm_supervisor
      )
      actor.continue(new_state)
    }
    user_types.UpdateKarma(delta) -> {
      let new_karma = state.karma + delta
      let new_state = user_types.UserState(
        state.username,
        new_karma,
        state.subscribed_subreddits,
        state.created_posts,
        state.created_comments,
        state.dm_conversations,
        state.subreddit_supervisor,
        state.dm_supervisor
      )
      actor.continue(new_state)
    }
    user_types.GetKarma() -> {
        // gotta reply to somebody the karma val except who?
        //gotta think about how client gonna do this
        actor.continue(state)
    }
    user_types.GetSubscribedSubreddits() -> {
        // reply to who? who wants this info?
        actor.continue(state)
    }
    
    user_types.JoinSubreddit(subreddit_name) ->{
        let new_subs = set.insert(state.subscribed_subreddits, subreddit_name)
        let new_state = user_types.UserState(
            state.username,
            state.karma,
            new_subs,
            state.created_posts,
            state.created_comments,
            state.dm_conversations,
            state.subreddit_supervisor,
            state.dm_supervisor
        )
        //TODO: also gotta send to subreddit actor to add this user to its member list
        actor.continue(new_state)
    }
    user_types.LeaveSubreddit(subreddit_name) ->{
        let new_subs = set.delete(state.subscribed_subreddits, subreddit_name)
        let new_state = user_types.UserState(
            state.username,
            state.karma,
            new_subs,
            state.created_posts,
            state.created_comments,
            state.dm_conversations,
            state.subreddit_supervisor,
            state.dm_supervisor
        )
        //TODO: also gotta send to subreddit actor to remove this user from its member list
        actor.continue(new_state)
    }
    user_types.CreatePost(subreddit_name, title, content, reply_with) -> {
        //send create to subreddit manager actor
        //add post id to created_posts set when get reply?
        actor.continue(state)
    }
    user_types.CreateComment(post_id, content, reply_with) -> {
        //send create to postmanageractor
        actor.continue(state)
    }
    user_types.VoteOnPost(post_id, vote_type, reply_with) -> {
        //send vote to postmanageractor
        actor.continue(state)
    }
    user_types.VoteOnComment(comment_id, vote_type, reply_with) -> {
        //send vote to commentmanageractor
        actor.continue(state)
    }
    user_types.SendDM(recipient_user, content, reply_with) -> {
        //send to dmmanageractor
        actor.continue(state)
    }
    user_types.GetDMConversations() -> {
        actor.continue(state)
    }
    _ -> actor.continue(state)
  }
}