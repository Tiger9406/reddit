import types.{type DMConversationId}
import gleam/set.{type Set}
import gleam/erlang/process.{type Subject}



pub type DMState{
    DMState(
        conversation_id: DMConversationId,
        messages: List(String),
        manager: Subject(DMManagerSupervisorMessage)
    )
}

pub type DMManagerSupervisorState{
    DMManagerSupervisorState(
        conversations: Set(Subject(DMActor))
    )
}

pub type DMActor{
    InitializeDMMessage(conversation_id: DMConversationId)
    SendMessage(content: String, sender_username: String)
    GetMessages(reply_with: String)
}

pub type DMManagerSupervisorMessage{
    InitializeDMManager()
    CreateDMConversation(conversation_id: DMConversationId)
    GetDMConversation(conversation_id: DMConversationId, reply_with: String)
}