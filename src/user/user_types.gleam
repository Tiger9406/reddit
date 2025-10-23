import gleam/dict.{type Dict}
import gleam/otp/actor
import gleam/erlang/process.{type Subject}
import gleam/set.{type Set}

import types.{type Username, type SubredditName, type PostId, type CommentId, type DMConversationId}

import subreddit/subreddit_types.{type SubredditSupervisorMessage}
import messaging/dm_types.{type DMManagerSupervisorMessage}


pub type UserState{
    UserState(
        username: Username,
        karma: Int,
        subscribed_subreddits: Set(SubredditName),
        created_posts: Set(PostId),
        created_comments: Set(CommentId),
        dm_conversations: Set(DMConversationId),
        subreddit_supervisor: Subject(SubredditSupervisorMessage),
        dm_supervisor: Subject(DMManagerSupervisorMessage)
    )
}

pub type UserMessage{
    Initialize(username: Username, subreddit_supervisor: Subject(SubredditSupervisorMessage), dm_supervisor: Subject(DMManagerSupervisorMessage))

    UpdateKarma(delta: Int) //who would be requesting update karma? needed to respond?
    GetKarma()
    
    //functions for client side to call; these internally call other engine actors
    JoinSubreddit(subreddit_name: SubredditName)
    LeaveSubreddit(subreddit_name: SubredditName)
    GetSubscribedSubreddits()
    CreatePost(
        subreddit_name: SubredditName,
        title: String,
        content: String,
        reply_with: String
    )
    CreateComment(
        post_id: PostId,
        content: String,
        reply_with: String
    )
    VoteOnPost(
        post_id: PostId,
        vote_type: String, // "upvote" | "downvote" | "remove"
        reply_with: String
    )
    VoteOnComment(
        comment_id: CommentId,
        vote_type: String, // "upvote" | "downvote" | "remove"
        reply_with: String
    )
    SendDM(
        recipient_user: Username,
        content: String,
        reply_with: String
    )
    GetDMConversations()
}
