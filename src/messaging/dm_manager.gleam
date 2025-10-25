import types
import gleam/otp/actor

pub fn dm_manager(state: types.DMManagerState, message: types.DMManagerMessage) -> actor.Next(types.DMManagerState, types.DMManagerMessage) {
    case message{
        _->{
            actor.continue(state)
        }
    }
}