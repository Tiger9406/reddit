


import gleam/erlang/process
import gleam/http/request
import gleam/http/response
import mist
import engine/engine_supervisor
import api/api_server
import gleam/bytes_tree

pub fn main() {
  let assert Ok(engine_subject) = engine_supervisor.start()

  let api_state = api_server.ApiState(engine: engine_subject)

  let assert Ok(_) =
    fn(req: request.Request(mist.Connection)) -> response.Response(mist.ResponseData) {
      // Route request to api_server
      api_server.handle_request(req, api_state)
      // convert response to bytes
      |> response.map(fn(body_string) {
        mist.Bytes(bytes_tree.from_string(body_string))
      })
    }
    |> mist.new
    |> mist.port(8080)
    |> mist.start

  process.sleep_forever()
}