import types.{type PostId, type Username, type SubredditName}

pub type PostActor{
    InitializePostMessage(post_id: PostId, author_username: Username, subreddit_name: SubredditName, title: String, content: String)
}