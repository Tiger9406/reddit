import gleam/dict
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/list
import gleam/option.{Some}
import mist
import types

pub type ApiState {
  ApiState(engine: Subject(types.EngineMessage))
}

pub type ApiResponse {
  ApiSuccess(message: String, data: json.Json)
  ApiError(message: String)
}


fn json_response(status: Int, body: String) -> Response(String) {
  response.new(status)
  |> response.set_body(body)
  |> response.set_header("content-type", "application/json")
  |> response.set_header("access-control-allow-origin", "*")
}

// 1. RAW JSON BUILDER
// This constructs the JSON string manually. 
// It prevents "Double Encoding" when the 'data' is already a JSON string.
fn success_json_raw(message: String, raw_data_json: String) -> String {
  let escaped_message = json.string(message) |> json.to_string()
  "{ \"status\": \"success\", \"message\": " <> escaped_message <> ", \"data\": " <> raw_data_json <> " }"
}

fn error_json(message: String) -> String {
  json.object([
    #("status", json.string("error")),
    #("message", json.string(message)),
  ])
  |> json.to_string()
}

// response_mapper must now always return a String (which is valid JSON)
fn make_engine_request(
  state: ApiState,
  msg_constructor: fn(Subject(Result(t, String))) -> types.EngineMessage,
  response_mapper: fn(t) -> String,
) -> Response(String) {
  let timeout = 3000 // 3 seconds
  let result = process.call(
    state.engine, 
    timeout, 
    fn(reply_subject) {
      msg_constructor(reply_subject)
    }
  )
  case result {
    Ok(data) -> {
      json_response(
        200, 
        // We inject the mapped string directly into the data field
        success_json_raw("Operation successful", response_mapper(data))
      )
    }
    Error(err_msg) -> json_response(400, error_json(err_msg))
  }
}

pub fn handle_request(
  req: Request(mist.Connection),
  state: ApiState,
) -> Response(String) {
  let path = request.path_segments(req)
  let method = req.method

  case method, path {
    // Users
    http.Post, ["api", "users"] -> create_user(req, state)
    http.Get, ["api", "users", username] -> get_user(username, state)
    http.Post, ["api", "users", username, "register_key"] -> register_public_key(req, username, state)
    http.Get, ["api", "users", username, "public_key"] -> get_public_key(username, state)
    http.Get, ["api", "users", username, "feed"] -> get_user_feed(username, state)

    // Subreddits
    http.Post, ["api", "subreddits"] -> create_subreddit(req, state)
    http.Post, ["api", "users", username, "subreddits", "join"] -> join_subreddit(req, username, state)
    http.Post, ["api", "users", username, "subreddits", "leave"] -> leave_subreddit(req, username, state)

    // Posts
    http.Post, ["api", "posts"] -> create_post(req, state)
    http.Get, ["api", "posts", post_id] -> get_post(post_id, state)
    http.Post, ["api", "posts", post_id, "upvote"] -> upvote_post(req, post_id, state)
    http.Post, ["api", "posts", post_id, "downvote"] -> downvote_post(req, post_id, state)

    // Comments
    http.Post, ["api", "comments"] -> create_comment(req, state)
    http.Post, ["api", "comments", comment_id, "upvote"] -> upvote_comment(req, comment_id, state)
    http.Post, ["api", "comments", comment_id, "downvote"] -> downvote_comment(req, comment_id, state)

    // DM
    http.Post, ["api", "messages"] -> send_dm(req, state)

    _, _ -> json_response(404, error_json("Endpoint not found"))
  }
}


fn create_user(req: Request(mist.Connection), state: ApiState) -> Response(String) {
  read_json_body(req, fn(dict) {
    case dict.get(dict, "username") {
      Ok(username) -> {
        make_engine_request(
          state,
          fn(reply) { types.EngineCreateUser(username, reply) },
          fn(created_name) { 
            json.object([#("username", json.string(created_name))]) 
            |> json.to_string() 
          }
        )
      }
      Error(_) -> json_response(400, error_json("couldn't get username"))
    }
  })
}

fn get_user(username: String, state: ApiState) -> Response(String) {
  make_engine_request(
    state,
    fn(reply) { types.EngineGetUser(username, reply) },
    fn(user_data_json_string) { user_data_json_string }
  )
}

fn create_subreddit(req: Request(mist.Connection), state: ApiState) -> Response(String) {
  read_json_body(req, fn(dict) {
    case dict.get(dict, "name"), dict.get(dict, "description") {
      Ok(name), Ok(desc) -> {
        make_engine_request(
          state,
          fn(reply) { types.EngineUserCreateSubreddit(name, desc, reply) },
          fn(created_name) { 
            json.object([#("subreddit", json.string(created_name))]) 
            |> json.to_string()
          }
        )
      }
      _, _ -> json_response(400, error_json("Missing 'name' or 'description'"))
    }
  })
}

fn join_subreddit(req: Request(mist.Connection), username: String, state: ApiState) -> Response(String) {
  read_json_body(req, fn(dict) {
    case dict.get(dict, "subreddit_name") {
      Ok(sub_name) -> {
        make_engine_request(
          state,
          fn(reply) { types.EngineUserJoinSubreddit(username, sub_name, reply) },
          fn(sub) { 
            json.object([
              #("username", json.string(username)),
              #("subreddit", json.string(sub)),
            ]) |> json.to_string()
          }
        )
      }
      Error(_) -> json_response(400, error_json("Missing 'subreddit_name'"))
    }
  })
}

fn leave_subreddit(req: Request(mist.Connection), username: String, state: ApiState) -> Response(String) {
  read_json_body(req, fn(dict) {
    case dict.get(dict, "subreddit_name") {
      Ok(sub_name) -> {
        make_engine_request(
          state,
          fn(reply) { types.EngineUserLeaveSubreddit(username, sub_name, reply) },
          fn(sub) { 
             json.object([
              #("username", json.string(username)),
              #("subreddit", json.string(sub)),
            ]) |> json.to_string()
          }
        )
      }
      Error(_) -> json_response(400, error_json("Missing 'subreddit_name'"))
    }
  })
}

fn create_post(req: Request(mist.Connection), state: ApiState) -> Response(String) {
  read_json_body(req, fn(dict) {
    let u = dict.get(dict, "username")
    let s = dict.get(dict, "subreddit_name")
    let t = dict.get(dict, "title")
    let c = dict.get(dict, "content")

    case u, s, t, c {
      Ok(u), Ok(s), Ok(t), Ok(c) -> {
        make_engine_request(
          state,
          fn(reply) { types.EngineUserCreatePost(u, s, t, c, reply) },
          fn(title) { 
             json.object([#("title", json.string(title))]) |> json.to_string()
          }
        )
      }
      _, _, _, _ -> json_response(400, error_json("Missing required fields"))
    }
  })
}

pub fn upvote_post(req: Request(mist.Connection), post_id: String, state: ApiState) -> Response(String) {
  handle_post_action(req, post_id, state, types.EngineUserLikesPost)
}

pub fn downvote_post(req: Request(mist.Connection), post_id: String, state: ApiState) -> Response(String) {
  handle_post_action(req, post_id, state, types.EngineUserDislikesPost)
}

fn handle_post_action(
  req: Request(mist.Connection),
  post_id: String,
  state: ApiState,
  msg_constructor: fn(String, String, Subject(Result(a, String))) -> types.EngineMessage,
) -> Response(String) {
  read_json_body(req, fn(dict) {
    case dict.get(dict, "username") {
      Ok(username) -> {
        make_engine_request(
          state,
          fn(reply) { msg_constructor(username, post_id, reply) },
          fn(_) { "null" } // Valid JSON null
        )
      }
      Error(_) -> json_response(400, error_json("Missing 'username'"))
    }
  })
}

pub fn get_post(post_id: types.PostId, state: ApiState) -> Response(String) {
  make_engine_request(
    state,
    fn(reply) { types.EngineUserGetsPost(post_id, reply) },
    // Assuming Engine returns the full JSON string for the post
    fn(post_json_string) { post_json_string }
  )
}

pub fn create_comment(req: Request(mist.Connection), state: ApiState) -> Response(String) {
  read_json_body(req, fn(dict) {
    let u = dict.get(dict, "username")
    let pid = dict.get(dict, "post_id")
    let parent = dict.get(dict, "parent_comment_id")
    let c = dict.get(dict, "content")

    case u, pid, parent, c {
      Ok(u), Ok(pid), Ok(parent), Ok(c) -> {
        make_engine_request(
          state,
          fn(reply) { types.EngineUserCreateComment(u, pid, Some(parent), c, reply) },
          fn(cid) { 
            json.object([#("comment_id", json.string(cid))]) |> json.to_string()
          }
        )
      }
      _, _, _, _ -> json_response(400, error_json("Missing fields"))
    }
  })
}

pub fn upvote_comment(req: Request(mist.Connection), comment_id: String, state: ApiState) -> Response(String) {
  handle_comment_action(req, comment_id, state, types.EngineUserUpvotesComment)
}

pub fn downvote_comment(req: Request(mist.Connection), comment_id: String, state: ApiState) -> Response(String) {
  handle_comment_action(req, comment_id, state, types.EngineUserDownvotesComment)
}

fn handle_comment_action(
  req: Request(mist.Connection),
  comment_id: String,
  state: ApiState,
  msg_constructor: fn(String, String, Subject(Result(String, String))) -> types.EngineMessage,
) -> Response(String) {
  read_json_body(req, fn(dict) {
    case dict.get(dict, "username") {
      Ok(username) -> {
        make_engine_request(
          state,
          fn(reply) { msg_constructor(username, comment_id, reply) },
          fn(_) { "null" }
        )
      }
      Error(_) -> json_response(400, error_json("Missing 'username'"))
    }
  })
}

pub fn send_dm(req: Request(mist.Connection), state: ApiState) -> Response(String) {
  read_json_body(req, fn(dict) {
    case dict.get(dict, "username"), dict.get(dict, "to"), dict.get(dict, "content") {
      Ok(from), Ok(to), Ok(content) -> {
        make_engine_request(
          state,
          fn(reply) { types.EngineUserSendDM(from, to, content, reply) },
          fn(_) { "null" }
        )
      }
      _, _, _ -> json_response(400, error_json("Missing fields"))
    }
  })
}

fn get_user_feed(username: String, state: ApiState) -> Response(String) {
  make_engine_request(
    state,
    fn(reply) { types.EngineGetUserFeed(username, reply) },
    fn(feed_list) {
      json.object([
        #("username", json.string(username)),
        #("feed", json.array(feed_list, of: json.string)),
        #("count", json.int(list.length(feed_list)))
      ]) |> json.to_string()
    }
  )
}

fn register_public_key(req: Request(mist.Connection), username: String, _state: ApiState) -> Response(String) {
  read_json_body(req, fn(dict) {
    case dict.get(dict, "public_key") {
      Ok(pk) -> {
        json_response(202, success_json_raw(
          "Request accepted", 
          json.object([
            #("username", json.string(username)), 
            #("public_key", json.string(pk))
          ]) |> json.to_string()
        ))
      }
      Error(_) -> json_response(400, error_json("Missing public_key"))
    }
  })
}

fn get_public_key(username: String, _state: ApiState) -> Response(String) {
  json_response(200, success_json_raw(
    "good", 
    json.object([
      #("username", json.string(username)),
      #("public_key", json.string("FAKE_KEY"))
    ]) |> json.to_string()
  ))
}

fn read_json_body(
  req: Request(mist.Connection), 
  handler: fn(dict.Dict(String, String)) -> Response(String)
) -> Response(String) {
  case mist.read_body(req, 1_048_576) {
    Ok(req_with_body) -> {
      case json.parse_bits(req_with_body.body, decode.dict(decode.string, decode.string)) {
        Ok(d) -> handler(d)
        Error(_) -> json_response(400, error_json("Invalid JSON format"))
      }
    }
    Error(_) -> json_response(400, error_json("Body too large or unreadable"))
  }
}