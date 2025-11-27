import gleam/bit_array
import gleam/dict
import gleam/dynamic/decode
import gleam/erlang/process.{type Subject}
import gleam/http
import gleam/http/request.{type Request}
import gleam/http/response.{type Response}
import gleam/json
import gleam/option.{Some}
import gleam/string
import gleam/list
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

fn success_json(message: String, data: json.Json) -> String {
  json.object([
    #("status", json.string("success")),
    #("message", json.string(message)),
    #("data", data),
  ])
  |> json.to_string()
}

fn error_json(message: String) -> String {
  json.object([
    #("status", json.string("error")),
    #("message", json.string(message)),
  ])
  |> json.to_string()
}

pub fn handle_request(
  req: Request(mist.Connection),
  state: ApiState,
) -> Response(String) {
  let path = request.path_segments(req)
  let method = req.method

  case method, path {
    http.Post, ["api", "users"] -> create_user(req, state)
    http.Get, ["api", "users", username] -> get_user(username, state)
    http.Post, ["api", "users", username, "register_key"] ->
      register_public_key(req, username, state)
    http.Get, ["api", "users", username, "public_key"] ->
      get_public_key(username, state)

    http.Post, ["api", "subreddits"] -> create_subreddit(req, state)
    http.Post, ["api", "users", username, "subreddits", "join"] ->
      join_subreddit(req, username, state)
    http.Post, ["api", "users", username, "subreddits", "leave"] ->
      leave_subreddit(req, username, state)

    http.Post, ["api", "posts"] -> create_post(req, state)
    http.Post, ["api", "posts", post_id, "upvote"] ->
      upvote_post(req, post_id, state)
    http.Post, ["api", "posts", post_id, "downvote"] ->
      downvote_post(req, post_id, state)
    http.Get, ["api", "posts", post_id] -> get_post(post_id, state)

    http.Post, ["api", "comments"] -> create_comment(req, state)
    http.Post, ["api", "comments", comment_id, "upvote"] ->
      upvote_comment(req, comment_id, state)
    http.Post, ["api", "comments", comment_id, "downvote"] ->
      downvote_comment(req, comment_id, state)

    http.Post, ["api", "messages"] -> send_dm(req, state)

    http.Get, ["api", "users", username, "feed"] ->
      get_user_feed(username, state)

    _, _ -> json_response(404, error_json("Endpoint not found"))
  }
}

fn make_engine_request(
  state: ApiState,
  // function: takes a Reply Channel and returns the Engine Message
  msg_constructor: fn(Subject(Result(t, String))) -> types.EngineMessage,
  // function: converts the success data into JSON
  response_mapper: fn(t) -> json.Json,
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
        success_json("Operation successful", response_mapper(data))
      )
    }
    Error(err_msg) -> json_response(400, error_json(err_msg))
  }
}

fn create_user(
  req: Request(mist.Connection),
  state: ApiState,
) -> Response(String) {
  case mist.read_body(req, 1_048_576) {
    Ok(req_with_body) -> {
      //now we have raw bitarray
      //convert to string
      case
        json.parse_bits(
          req_with_body.body,
          decode.dict(decode.string, decode.string),
        )
      {
        Ok(result_dict) -> {
          case dict.get(result_dict, "username") {
            Ok(username) -> {
              make_engine_request(
                state,
                fn(reply) { types.EngineCreateUser(username, reply) },
                fn(created_name) { json.object([#("username", json.string(created_name))]) }
              )
            }
            Error(_) -> json_response(400, error_json("couldn't get username"))
          }
        }
        Error(_) -> json_response(400, error_json("couldn't decode into dict"))
      }
    }
    Error(_) -> json_response(400, error_json("Invalid Json; maybe too big"))
  }
}

fn get_user(username: String, state: ApiState) -> Response(String) {
  //to_do
  
}

fn register_public_key(
  req: Request(mist.Connection),
  username: String,
  state: ApiState,
) -> Response(String) {
  case mist.read_body(req, 1_048_576) {
    Ok(req_with_body) -> {
      case
        json.parse_bits(
          req_with_body.body,
          decode.dict(decode.string, decode.string),
        )
      {
        Ok(result_dict) -> {
          case dict.get(result_dict, "public_key") {
            Ok(public_key) -> {
              //gotta store public key
              json_response(
                202,
                success_json(
                  "Request accepted, processing",
                  json.object([
                    #("username", json.string(username)),
                    #("public_key", json.string(public_key)),
                  ]),
                ),
              )
            }
            Error(_) ->
              json_response(400, error_json("couldn't get public key"))
          }
        }
        Error(_) -> json_response(400, error_json("couldn't decode into dict"))
      }
    }
    Error(_) -> json_response(400, error_json("Invalid Json; maybe too big"))
  }
}

fn get_public_key(username: String, state: ApiState) -> Response(String) {
  //todo
  //retrieve key & return
}

fn create_subreddit(
  req: Request(mist.Connection),
  state: ApiState,
) -> Response(String) {
  case mist.read_body(req, 1_048_576) {
    Ok(req_with_body) -> {
      case
        json.parse_bits(
          req_with_body.body,
          decode.dict(decode.string, decode.string),
        )
      {
        Ok(result_dict) -> {
          let name_result = dict.get(result_dict, "name")
          let desc_result = dict.get(result_dict, "description")

        
          case name_result, desc_result {
            Ok(name), Ok(desc) -> {
              make_engine_request(
                state,
                fn(reply) { types.EngineUserCreateSubreddit(name, desc, reply) },
                fn(created_name) { json.object([#("subreddit", json.string(created_name))]) }
              )
            }
            _, _ ->
              json_response(400, error_json("Missing 'name' or 'description'"))
          }
        }
        Error(_) -> json_response(400, error_json("Invalid JSON"))
      }
    }
    Error(_) -> json_response(400, error_json("Body error"))
  }
}

fn join_subreddit(
  req: Request(mist.Connection),
  username: String,
  state: ApiState,
) -> Response(String) {
  case mist.read_body(req, 1_048_576) {
    Ok(req_with_body) -> {
      case
        json.parse_bits(
          req_with_body.body,
          decode.dict(decode.string, decode.string),
        )
      {
        Ok(result_dict) -> {
          case dict.get(result_dict, "subreddit_name") {
            Ok(sub_name) -> {
              make_engine_request(
                state,
                fn(reply) { types.EngineUserJoinSubreddit(username, sub_name, reply) },
                fn(subreddit_name) { json.object([
                    #("username", json.string(username)),
                    #("subreddit", json.string(subreddit_name)),
                  ]) 
                }
              )
            }
            Error(_) ->
              json_response(400, error_json("Missing 'subreddit_name'"))
          }
        }
        Error(_) -> json_response(400, error_json("Invalid JSON"))
      }
    }
    Error(_) -> json_response(400, error_json("Body error"))
  }
}

fn leave_subreddit(
  req: Request(mist.Connection),
  username: String,
  state: ApiState,
) -> Response(String) {
  case mist.read_body(req, 1_048_576) {
    Ok(req_with_body) -> {
      case
        json.parse_bits(
          req_with_body.body,
          decode.dict(decode.string, decode.string),
        )
      {
        Ok(result_dict) -> {
          case dict.get(result_dict, "subreddit_name") {
            Ok(sub_name) -> {
              make_engine_request(
                state,
                fn(reply) { types.EngineUserLeaveSubreddit(username, sub_name, reply) },
                fn(subreddit_name) { json.object([
                    #("username", json.string(username)),
                    #("subreddit", json.string(subreddit_name)),
                  ]) 
                }
              )
            }
            Error(_) ->
              json_response(400, error_json("Missing 'subreddit_name'"))
          }
        }
        Error(_) -> json_response(400, error_json("Invalid JSON"))
      }
    }
    Error(_) -> json_response(400, error_json("Body error"))
  }
}

fn create_post(
  req: Request(mist.Connection),
  state: ApiState,
) -> Response(String) {
  case mist.read_body(req, 1_048_576) {
    Ok(req_with_body) -> {
      case
        json.parse_bits(
          req_with_body.body,
          decode.dict(decode.string, decode.string),
        )
      {
        Ok(result_dict) -> {
          let user_res = dict.get(result_dict, "username")
          let sub_res = dict.get(result_dict, "subreddit_name")
          let title_res = dict.get(result_dict, "title")
          let content_res = dict.get(result_dict, "content")

          case user_res, sub_res, title_res, content_res {
            Ok(u), Ok(s), Ok(t), Ok(c) -> {
              make_engine_request(
                state,
                fn(reply) { types.EngineUserCreatePost(u, s, t, c, reply) },
                fn(title_returned) { json.object([#("title", json.string(title_returned))]) }
              )
            }
            _, _, _, _ ->
              json_response(
                400,
                error_json(
                  "Missing required fields (username, subreddit_name, title, content)",
                ),
              )
          }
        }
        Error(_) -> json_response(400, error_json("Invalid JSON"))
      }
    }
    Error(_) -> json_response(400, error_json("Body error"))
  }
}

pub fn upvote_post(
  req: Request(mist.Connection),
  post_id: String,
  state: ApiState,
) -> Response(String) {
  handle_post_action(req, post_id, state, types.EngineUserLikesPost)
}

pub fn downvote_post(
  req: Request(mist.Connection),
  post_id: String,
  state: ApiState,
) -> Response(String) {
  handle_post_action(req, post_id, state, types.EngineUserDislikesPost)
}

// Helper for post upvote/downvote to reduce duplication
fn handle_post_action(
  req: Request(mist.Connection),
  post_id: String,
  state: ApiState,
  msg_constructor: fn(String, String, Subject(Result(a, String))) -> types.EngineMessage,
) -> Response(String) {
  case mist.read_body(req, 1_048_576) {
    Ok(req_with_body) -> {
      case
        json.parse_bits(
          req_with_body.body,
          decode.dict(decode.string, decode.string),
        )
      {
        Ok(result_dict) -> {
          case dict.get(result_dict, "username") {
            Ok(username) -> {
              make_engine_request(
                state,
                fn(reply) { msg_constructor(username, post_id, reply) },
                fn(_) { json.null() }
              )
            }
            Error(_) -> json_response(400, error_json("Missing 'username'"))
          }
        }
        Error(_) -> json_response(400, error_json("Invalid JSON"))
      }
    }
    Error(_) -> json_response(400, error_json("Body error"))
  }
}

pub fn get_post(post_id: types.PostId, state: ApiState) -> Response(String) {
  make_engine_request(
    state,
    fn(reply) { types.EngineUserGetsPost(post_id, reply) },
    fn(post_data) {
      //todo
      //convert post_data to json
      json.object([
        #("post_id", json.string(post_id)),
        // add other post fields here
      ])
    }
  )
}

pub fn create_comment(
  req: Request(mist.Connection),
  state: ApiState,
) -> Response(String) {
  case mist.read_body(req, 1_048_576) {
    Ok(req_with_body) -> {
      case
        json.parse_bits(
          req_with_body.body,
          decode.dict(decode.string, decode.string),
        )
      {
        Ok(result_dict) -> {
          let user_res = dict.get(result_dict, "username")
          let post_res = dict.get(result_dict, "post_id")
          let parent_res = dict.get(result_dict, "parent_comment_id")
          let content_res = dict.get(result_dict, "content")

          case user_res, post_res, parent_res, content_res {
            Ok(u), Ok(pid), Ok(parent), Ok(c) -> {
              make_engine_request(
                state,
                fn(reply) { types.EngineUserCreateComment(u, pid, Some(parent), c, reply) },
                fn(comment_data) {
                  //todo
                  //convert comment_data to json
                  json.object([
                    #("comment_id", json.string(comment_data)),
                  ])
                }
              )
            }
            _, _, _, _ ->
              json_response(
                400,
                error_json(
                  "Missing fields (username, post_id, parent_comment_id, content)",
                ),
              )
          }
        }
        Error(_) -> json_response(400, error_json("Invalid JSON"))
      }
    }
    Error(_) -> json_response(400, error_json("Body error"))
  }
}

pub fn upvote_comment(
  req: Request(mist.Connection),
  comment_id: String,
  state: ApiState,
) -> Response(String) {
  handle_comment_action(req, comment_id, state, types.EngineUserUpvotesComment)
}

pub fn downvote_comment(
  req: Request(mist.Connection),
  comment_id: String,
  state: ApiState,
) -> Response(String) {
  handle_comment_action(req, comment_id, state, types.EngineUserDownvotesComment)
}

// helper for comment actions
fn handle_comment_action(
  req: Request(mist.Connection),
  comment_id: String,
  state: ApiState,
  msg_constructor: fn(String, String, Subject(Result(String, String))) -> types.EngineMessage,
) -> Response(String) {
  case mist.read_body(req, 1_048_576) {
    Ok(req_with_body) -> {
      case
        json.parse_bits(
          req_with_body.body,
          decode.dict(decode.string, decode.string),
        )
      {
        Ok(result_dict) -> {
          case dict.get(result_dict, "username") {
            
            Ok(username) -> {
              make_engine_request(
                state,
                fn(reply) { msg_constructor(username, comment_id, reply) },
                fn(_) { json.null() }
              )
            }
            Error(_) -> json_response(400, error_json("Missing 'username'"))
          }
        }
        Error(_) -> json_response(400, error_json("Invalid JSON"))
      }
    }
    Error(_) -> json_response(400, error_json("Body error"))
  }
}

pub fn send_dm(
  req: Request(mist.Connection),
  state: ApiState,
) -> Response(String) {
  case mist.read_body(req, 1_048_576) {
    Ok(req_with_body) -> {
      case
        json.parse_bits(
          req_with_body.body,
          decode.dict(decode.string, decode.string),
        )
      {
        Ok(result_dict) -> {
          let from_res = dict.get(result_dict, "username")
          let to_res = dict.get(result_dict, "to")
          let content_res = dict.get(result_dict, "content")

          case from_res, to_res, content_res {
            Ok(from), Ok(to), Ok(content) -> {
              make_engine_request(
                state,
                fn(reply) { types.EngineUserSendDM(from, to, content, reply) },
                fn(_) { json.null() }
              )
            }
            _, _, _ ->
              json_response(
                400,
                error_json("Missing fields (username, to, content)"),
              )
          }
        }
        Error(_) -> json_response(400, error_json("Invalid JSON"))
      }
    }
    Error(_) -> json_response(400, error_json("Body error"))
  }
}

fn get_user_feed(username: String, state: ApiState) -> Response(String) {
  make_engine_request(
    state,
    fn(reply) { types.EngineGetUserFeed(username, reply) },
    // convert list(string) to json
    fn(feed_list) {
      json.object([
        #("username", json.string(username)),
        #("feed", json.array(feed_list, of: json.string)),
        #("count", json.int(list.length(feed_list)))
      ])
    }
  )
}