import gleam/json
import types
import gleam/otp/actor
import gleam/list
import gleam/erlang/process

pub fn dm_actor(state: types.DMActorState, message: types.DMActorMessage) -> actor.Next(types.DMActorState, types.DMActorMessage) {
    case message{
        types.DMActorSendMessage(sender_username, content) -> {
            let new_message = sender_username <> ": " <> content
            let new_list = [new_message]
            let new_messages = list.append(state.messages, new_list)
            let new_state = types.DMActorState(
                state.conversation_id,
                new_messages
            )
            actor.continue(new_state)
        }
        types.DMActorGetMessages(reply_to, _from_username) -> {
            process.send(reply_to, Ok(json.to_string(json.array(
                state.messages,
                of: json.string
            ))))
            actor.continue(state)
        }
    }
}