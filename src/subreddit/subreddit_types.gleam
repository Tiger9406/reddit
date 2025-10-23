import types.{type SubredditName}
import gleam/erlang/process.{type Subject}
import gleam/dict.{type Dict}
import post/post_types.{type PostActor}

pub type SubredditState{
    SubredditState(
        name: SubredditName,
        description: String,
        subscribers: Int,
        posts: Dict(String, Subject(PostActor))
    )
}

pub type SubredditMessage{
    Initialize(name: SubredditName, description: String)
    AddSubscriber(username: String)
    RemoveSubscriber(username: String)
    GetSubscriberCount(reply_with: String)
    GetSubscribers(reply_with: String)

}

pub type SubredditSupervisorMessage{
    CreateSubreddit(name: SubredditName, description: String)
}