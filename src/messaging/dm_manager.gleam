import types
import gleam/otp/actor
import gleam/erlang/process
import gleam/dict
import gleam/list
import messaging/dm_actor.{dm_actor}

pub fn dm_manager(state: types.DMManagerState, message: types.DMManagerMessage) -> actor.Next(types.DMManagerState, types.DMManagerMessage) {
    case message{
        types.SendDM(from_username, to_username, content) -> {
            let user_pair = #(from_username, to_username)
            let alternative_pair = #(to_username, from_username)
            case dict.get(state.conversations, user_pair){
                Ok(conversation_id) -> {
                    //existing conversation
                    let dm_actor = dict.get(state.subjects, conversation_id)
                    case dm_actor {
                        Ok(dm_actor) -> {
                            process.send(dm_actor, types.DMActorSendMessage(from_username, content))
                            actor.continue(state)
                        }
                        Error(_) -> {
                            actor.continue(state)
                        }
                    }
                }
                Error(_) -> {
                    case dict.get(state.conversations, alternative_pair){
                        Ok(conversation_id) -> {
                            let dm_actor = dict.get(state.subjects, conversation_id)
                            case dm_actor {
                                Ok(dm_actor) -> {
                                    process.send(dm_actor, types.DMActorSendMessage(from_username, content))
                                    actor.continue(state)
                                }
                                Error(_) -> {
                                    actor.continue(state)
                                }
                            }
                        }
                        Error(_) -> {
                            //create new conversation
                            let new_conversation_id = "dm_" <> from_username <> "_" <> to_username //simple id generation
                            let initial_state = types.DMActorState(
                                new_conversation_id,
                                list.new()
                            )
                            let assert Ok(actor) = actor.new(initial_state) |> actor.on_message(dm_actor) |> actor.start()
                            let subject = actor.data
                            let new_conversations = dict.insert(state.conversations, user_pair, new_conversation_id)
                            let new_subjects = dict.insert(state.subjects, new_conversation_id, subject)
                            let new_state = types.DMManagerState(
                                state.user_pairs,
                                new_conversations,
                                new_subjects
                            )
                            process.send(subject, types.DMActorSendMessage(from_username, content))
                            actor.continue(new_state)
                        }
                    }
                }
            }
        }
        types.GetDMConversationBetweenUsers(from_username, to_username, reply_to) -> {
            let user_pair = #(from_username, to_username)
            let alternative_pair = #(to_username, from_username)
            case dict.get(state.conversations, user_pair){
                Ok(conversation_id) -> {
                    let dm_actor = dict.get(state.subjects, conversation_id)
                    case dm_actor {
                        Ok(dm_actor) -> {
                            process.send(dm_actor, types.DMActorGetMessages(reply_to, from_username))
                            actor.continue(state)
                        }
                        Error(_) -> {
                            actor.continue(state)
                        }
                    }
                }
                Error(_) -> {
                    case dict.get(state.conversations, alternative_pair){
                        Ok(conversation_id) -> {
                            let dm_actor = dict.get(state.subjects, conversation_id)
                            case dm_actor {
                                Ok(dm_actor) -> {
                                    process.send(dm_actor, types.DMActorGetMessages(reply_to, from_username))
                                    actor.continue(state)
                                }
                                Error(_) -> {
                                    actor.continue(state)
                                }
                            }
                        }
                        Error(_) -> {
                            actor.continue(state)
                        }
                    }
                }
            }
        }
        types.GetDMConversation(_conversation_id, _reply_to, _username)->{
            //continue for now
            actor.continue(state)
        }
        types.DMManagerGetAllDMs(reply_to)->{
            process.send(reply_to, types.EngineReceiveAllDMs(state))
            actor.continue(state)
        }
    }
}