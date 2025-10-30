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
    UserGetAll(username: Username, reply_to: Subject(EngineReceiveMessage))
    
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
        dm_manager: Subject(DMManagerMessage),
    )
}

pub type UserManagerMessage{
    UserManagerInitialize(subreddit_manager: Subject(SubredditManagerMessage), dm_manager: Subject(DMManagerMessage))
    UserManagerCreateUser(username: Username)
    UserManagerGetUser(username: Username, reply_to: Subject(EngineReceiveMessage))
    
    UserManagerUserJoinSubreddit(username: Username, subreddit_name: SubredditName)
    UserManagerUserLeaveSubreddit(username: Username, subreddit_name: SubredditName)
    UserManagerUserCreatePost(username: Username, subreddit_name: SubredditName, title: String, content: String)
    UserManagerUserCreateComment(username: Username, post_id: PostId, comment_id: Option(CommentId), content: String)
    UserManagerUserUpvotePost(username: Username, post_id: PostId)
    UserManagerUserDownvotePost(username: Username, post_id: PostId)
    UserManagerUserSendDM(username: Username, other_username: Username, content: String)
    UserManagerUpdateKarma(username: Username, delta: Int)

    UserManagerGetAllUsers(reply_to: Subject(EngineReceiveMessage))
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
    SubredditGetAll(username: Username, reply_to: Subject(EngineReceiveMessage))

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
    SubredditManagerGetSubreddit(subreddit_name: SubredditName, reply_to: Subject(EngineReceiveMessage), username: Username)

    SubredditManagerCreateSubreddit(name: SubredditName, description: String)
    SubredditManagerAddSubscriberToSubreddit(subreddit_name: SubredditName, username: Username, user_actor: Subject(UserMessage))
    SubredditManagerRemoveSubscriberFromSubreddit(subreddit_name: SubredditName, username: Username, user_actor: Subject(UserMessage))    
    SubredditManagerCreatedPostInSubreddit(subreddit_name: SubredditName, post_id: PostId)

    SubredditManagerGetAllSubreddits(reply_to: Subject(EngineReceiveMessage))
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
    PostUpvote(username: Username, user_manager: Subject(UserManagerMessage))
    PostDownvote(username: Username, user_manager: Subject(UserManagerMessage))
    PostGetScore(username: Username, reply_to: Subject(EngineReceiveMessage))
    PostAddComment(comment_id: CommentId)
    PostGetAll(username: Username, reply_to: Subject(EngineReceiveMessage))
}

pub type PostManagerState{
    PostManagerState(
        posts: Dict(PostId, Subject(PostMessage)),
        number_of_posts: Int,
        comment_manager: Subject(CommentManagerMessage),
        user_manager: Option(Subject(UserManagerMessage))
    )
}

pub type PostManagerMessage{
    PostManagerGetPost(post_id: PostId, reply_to: Subject(EngineReceiveMessage), username: Username)

    PostManagerSetUserManager(user_manager: Subject(UserManagerMessage))

    PostManagerCreatePost(author_username: Username, subreddit_name: SubredditName, title: String, content: String, user_actor: Subject(UserMessage))
    PostManagerUpvote(post_id: PostId, username: Username)
    PostManagerDownvote(post_id: PostId, username: Username)
    PostManagerAddCommentToPost(post_id: PostId, comment_id: CommentId)

    PostManagerGetAllPosts(reply_to: Subject(EngineReceiveMessage))
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
    CommentUpvote(username: Username, user_manager: Subject(UserManagerMessage))
    CommentDownvote(username: Username, user_manager: Subject(UserManagerMessage))
    CommentAddReply(reply_comment_id: CommentId)
    CommentGetAll(username: Username, reply_to: Subject(EngineReceiveMessage))
}

pub type CommentManagerState{
    CommentManagerState(
        comments: Dict(CommentId, Subject(CommentMessage)),
        number_of_comments: Int,
        post_manager: Option(Subject(PostManagerMessage)),
        user_manager: Option(Subject(UserManagerMessage))
    )
}

pub type CommentManagerMessage{
    CommentManagerGetComment(comment_id: CommentId, reply_to: Subject(EngineReceiveMessage), username: Username)

    CommentManagerSetUserManager(user_manager: Subject(UserManagerMessage))
    CommentManagerSetPostManager(post_manager: Subject(PostManagerMessage))

    CommentManagerCreateComment(author_username: Username, content: String, post_id: PostId, parent: Option(CommentId), user_actor: Subject(UserMessage))
    CommentManagerUpvoteComment(comment_id: CommentId, username: Username)
    CommentManagerDownvoteComment(comment_id: CommentId, username: Username)
    CommentManagerGetAllComments(reply_to: Subject(EngineReceiveMessage))
}


pub type DMActorState{
    DMActorState(
        conversation_id: DMConversationId,
        messages: List(String),
    )
}

pub type DMManagerState{
    DMManagerState(
        user_pairs: Dict(Username, Set(Username)),
        conversations: Dict(#(Username, Username), DMConversationId),
        subjects: Dict(DMConversationId, Subject(DMActorMessage))
    )
}

pub type DMActorMessage{
    DMActorSendMessage(content: String, sender_username: String)
    DMActorGetMessages(reply_to: Subject(EngineReceiveMessage), from_username: String)
}

pub type DMManagerMessage{
    SendDM(username: Username, other_username: Username, content: String)
    GetDMConversation(conversation_id: DMConversationId, reply_to: Subject(EngineReceiveMessage), username: Username)
    GetDMConversationBetweenUsers(from_username: Username, to_username: Username, reply_to: Subject(EngineReceiveMessage))
    DMManagerGetAllDMs(reply_to: Subject(EngineReceiveMessage))
}

pub type EngineState {
    EngineState(
        user_manager: Subject(UserManagerMessage),
        subreddit_manager: Subject(SubredditManagerMessage),
        post_manager: Subject(PostManagerMessage),
        comment_manager: Subject(CommentManagerMessage),
        dm_manager: Subject(DMManagerMessage),
        engine_receive: Subject(EngineReceiveMessage)
    )
}

pub type EngineMessage {
    EngineGetUserManager(reply_with: Subject(Subject(UserManagerMessage)))
    EngineGetSubredditManager(reply_with: Subject(Subject(SubredditManagerMessage)))

    EngineCreateUser(username: Username)
    EngineUserCreateSubreddit(subreddit_name: SubredditName, description: String)
    EngineUserJoinSubreddit(username: Username, subreddit_name: SubredditName)
    EngineUserLeaveSubreddit(username: Username, subreddit_name: SubredditName)

    EngineUserCreatePost(username: Username, subreddit_name: SubredditName, title: String, content: String)
    EngineUserLikesPost(username: Username, post_id: PostId)
    EngineUserDislikesPost(username: Username, post_id: PostId)

    EngineUserCreateComment(username: Username, post_id: PostId, parent_comment_id: Option(CommentId), content: String)
    EngineUserUpvotesComment(username: Username, comment_id: CommentId)
    EngineUserDownvotesComment(username: Username, comment_id: CommentId)

    EngineUserSendDM(username: Username, other_username: Username, content: String)

    EngineGetAllSubreddits()
    EngineGetAllPosts()
    EngineGetAllComments()
    EngineGetAllUsers()
    EngineGetAllDMs()

    Shutdown
}

pub type EngineReceiveState{
    EngineReceiveState()
}
pub type EngineReceiveMessage{
    EngineReceiveUser(username: Username, user_state: UserState)
    EngineReceiveDMMessages(username: Username, message_state: DMActorState)
    EngineReceiveCommentData(username: Username, comment_state: CommentState)
    EngineReceiveSubredditDetails(username: Username, subreddt_state: SubredditState)
    EngineReceivePostDetails(username: Username, post_state: PostState)

    EngineReceiveAllComments(CommentManagerState)
    EngineReceiveAllDMs(DMManagerState)
    EngineReceiveAllPosts(PostManagerState)
    EngineReceiveAllSubreddits(SubredditManagerState)
    EngineReceiveAllUsers(UserManagerState)
}