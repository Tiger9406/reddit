import types.{type CommentId, type Username, type PostId}
import gleam/erlang/process.{type Subject}

pub type CommentActor{
    InitializeCommentMessage(
        comment_id: CommentId, 
        author_username: Username, 
        parent_post_id: PostId, 
        parent_comment: Subject(CommentActor), 
        children_comment: List(Subject(CommentActor)),
        content: String
    )
}