pub type Username = String
pub type SubredditName = String
pub type PostId = String
pub type CommentId = String
pub type DMConversationId = String

import gleam/set.{type Set}
import gleam/dict.{type Dict}
import gleam/option.{type Option}
import gleam/erlang/process.{type Subject}


pub type UserState{
    UserState(
        username: Username,
        karma: Int,
        subscribed_subreddits: Set(SubredditName),
        created_posts: Set(PostId),
        created_comments: Set(CommentId),
        dm_conversations: Set(DMConversationId),
    )
}

pub type UserMessage{
    UserInitialize(username: Username)

    UserGetKarma()
    UserGetSubscribedSubreddits()
    UserGetDMConversations()
    
    //update messages
    UserJoinedSubreddit(subreddit_name: SubredditName)
    UserLeftSubreddit(subreddit_name: SubredditName)
    UserUpdateKarma(delta: Int) //who would be requesting update karma? needed to respond?
    UserPostCreated(post_id: PostId) 
    UserCommentCreated(comment_id: CommentId)
}

pub type UserManagerState{
    UserManagerState(
        users: Dict(Username, Subject(UserMessage)),
        number_users: Int,
        subreddit_manager: Subject(SubredditManagerMessage),
        post_manager: Subject(PostManagerMessage),
        comment_manager: Subject(CommentManagerMessage),
        dm_supervisor: Subject(DMManagerSupervisorMessage),
    )
}

pub type UserManagerMessage{
    UserManagerInitialize(subreddit_manager: Subject(SubredditManagerMessage), dm_supervisor: Subject(DMManagerSupervisorMessage))
    UserManagerCreateUser(username: Username, reply_with: String)
    UserManagerGetUser(username: Username, reply_with: String)
    UserManagerGetNumberUsers(reply_with: String)
    UserManagerUserJoinSubreddit(username: Username, subreddit_name: SubredditName)
    UserManagerUserLeaveSubreddit(username: Username, subreddit_name: SubredditName)
    UserManagerUserCreatePost(username: Username, subreddit_name: SubredditName, title: String, content: String)
    UserManagerUserCreateComment(username: Username, post_id: PostId, comment_id: Option(CommentId), content: String)
    UserManagerUserUpvotePost(username: Username, post_id: PostId)
    UserManagerUserDownvotePost(username: Username, post_id: PostId)
    UserManagerUserSendDM(username: Username, other_username: Username, content: String)
    UserManagerUpdateKarma(username: Username, delta: Int)
}

pub type SubredditState{
    SubredditState(
        name: SubredditName,
        description: String,
        subscribers: Set(Username),
        posts: Set(PostId),
        number_of_subscribers: Int,
        number_posts: Int
    )
}

pub type SubredditMessage{
    SubredditInitialize(name: SubredditName, description: String)
    SubredditGetSubscriberCount(reply_with: String)
    SubredditGetSubscribers(reply_with: String)

    SubredditAddSubscriber(username: String, user_actor: Subject(UserMessage))
    SubredditRemoveSubscriber(username: String, user_actor: Subject(UserMessage))
    SubredditCreatePost(post_id: PostId)
}

pub type SubredditManagerState{
    SubredditManagerState(
        subreddits: Dict(SubredditName, Subject(SubredditMessage)),
        number_of_subreddits: Int,
        post_manager: Subject(PostManagerMessage)
    )
}

pub type SubredditManagerMessage{
    SubredditManagerGetSubreddit(subreddit_name: SubredditName, reply_with: String)

    SubredditManagerCreateSubreddit(name: SubredditName, description: String)
    SubredditManagerAddSubscriberToSubreddit(subreddit_name: SubredditName, username: Username, user_actor: Subject(UserMessage))
    SubredditManagerRemoveSubscriberFromSubreddit(subreddit_name: SubredditName, username: Username, user_actor: Subject(UserMessage))    
    SubredditManagerCreatedPostInSubreddit(subreddit_name: SubredditName, post_id: PostId)
}

pub type PostState{
    PostState(
        post_id: PostId,
        author_username: Username,
        subreddit_name: SubredditName,
        title: String,
        content: String,
        upvotes: Set(Username),
        downvotes: Set(Username),
        comments: Set(CommentId)
    )
}

pub type PostMessage{
    PostInitialize(post_id: PostId, author_username: Username, subreddit_name: SubredditName, title: String, content: String)
    PostUpvote(username: Username, user_manager: Subject(UserManagerMessage))
    PostDownvote(username: Username, user_manager: Subject(UserManagerMessage))
    PostGetScore(reply_with: String)
    PostAddComment(comment_id: CommentId)
}

pub type PostManagerState{
    PostManagerState(
        posts: Dict(PostId, Subject(PostMessage)),
        number_of_posts: Int,
        comment_manager: Subject(CommentManagerMessage),
        user_manager: Subject(UserManagerMessage)
    )
}

pub type PostManagerMessage{
    PostManagerInitialize()
    PostManagerGetPost(post_id: PostId, reply_with: String)

    PostManagerCreatePost(author_username: Username, subreddit_name: SubredditName, title: String, content: String, user_actor: Subject(UserMessage))
    PostManagerUpvote(post_id: PostId, username: Username)
    PostManagerDownvote(post_id: PostId, username: Username)
    PostManagerAddCommentToPost(post_id: PostId, comment_id: CommentId)
}

pub type CommentState{
    CommentState(
        comment_id: CommentId,
        author_username: Username,
        content: String,
        upvotes: Set(Username),
        downvotes: Set(Username),
        post: PostId,
        parent: Option(CommentId),
        replies: Set(CommentId)
    )
}

pub type CommentMessage{
    CommentInitialize(comment_id: CommentId, author_username: Username, content: String)
    CommentUpvote(username: Username, user_manager: Subject(UserManagerMessage))
    CommentDownvote(username: Username, user_manager: Subject(UserManagerMessage))
    CommentGetScore(reply_with: String)
    CommentAddReply(reply_comment_id: CommentId)
}

pub type CommentManagerState{
    CommentManagerState(
        comments: Dict(CommentId, Subject(CommentMessage)),
        number_of_comments: Int,
        post_manager: Subject(PostManagerMessage),
        user_manager: Subject(UserManagerMessage)
    )
}

pub type CommentManagerMessage{
    CommentManagerInitialize()
    CommentManagerGetComment(comment_id: CommentId, reply_with: String)

    CommentManagerCreateComment(author_username: Username, content: String, post_id: PostId, parent: Option(CommentId), user_actor: Subject(UserMessage))
    CommentManagerCreateReplyComment(author_username: Username, parent_comment_id: CommentId, content: String, user_actor: Subject(UserMessage))
    CommentManagerUpvoteComment(comment_id: CommentId, username: Username)
    CommentManagerDownvoteComment(comment_id: CommentId, username: Username)
}


pub type DMState{
    DMState(
        conversation_id: DMConversationId,
        messages: List(String),
        manager: Subject(DMManagerSupervisorMessage)
    )
}

pub type DMManagerSupervisorState{
    DMManagerSupervisorState(
        conversations: Set(Subject(DMActorMessage))
    )
}

pub type DMActorMessage{
    InitializeDMMessage(conversation_id: DMConversationId)
    SendMessage(content: String, sender_username: String)
    GetMessages(reply_with: String)
}

pub type DMManagerSupervisorMessage{
    InitializeDMManager()
    SendDM(username: Username, other_username: Username, content: String, user_actor: Subject(UserMessage), other_user_actor: Subject(UserMessage))
    GetDMConversation(conversation_id: DMConversationId, reply_with: String)
}