import argv
import gleam/http/request
import gleam/http/response
import gleam/http
import gleam/httpc
import gleam/io
import gleam/json
import gleam/string
import gleam/list
import gleam/dynamic/decode
import gleam/dynamic

const base_url = "http://localhost:8080/api"

@external(erlang, "io", "get_line")
fn native_get_line(prompt: String) -> dynamic.Dynamic

fn get_input(prompt: String) -> Result(String, Nil) {
  let raw = native_get_line(prompt)
  // dynamic.string used to check if it's a binary string
  case decode.run(raw, decode.string) {
    Ok(s) -> Ok(s)
    Error(_) -> Error(Nil)
  }
}

pub fn main() {
  let args = argv.load().arguments
  case args {
    [] -> {
      io.println("--- Gleam Reddit Client ---")
      io.println("Enter commands below (type 'help' for usage, 'exit' to quit)")
      run_repl()
    }
    _ -> handle_command(args)
  }
}

fn run_repl() {
  // use our local input wrapper (external)
  case get_input("client> ") {
    Ok(line) -> {
      let clean_line = string.trim(line)
      case clean_line {
        "exit" -> Nil
        "quit" -> Nil
        "" -> run_repl()
        _ -> {
          let parts = parse_args(clean_line)
          handle_command(parts)
          run_repl()
        }
      }
    }
    Error(_) -> Nil // Handle EOF
  }
}

// arg parser that works with quotes
fn parse_args(input: String) -> List(String) {
  parse_args_loop(input, "", [], False)
}

fn parse_args_loop(
  input: String,
  current: String,
  acc: List(String),
  in_quote: Bool,
) -> List(String) {
  case string.pop_grapheme(input) {
    // found quote
    Ok(#("\"", rest)) -> {
      parse_args_loop(rest, current, acc, !in_quote)
    }
    
    // found space outside quotes, complete current token
    Ok(#(" ", rest)) if !in_quote -> {
      case current {
        "" -> parse_args_loop(rest, "", acc, False)
        _ -> parse_args_loop(rest, "", [current, ..acc], False)
      }
    }
    
    // any other character
    Ok(#(char, rest)) -> {
      parse_args_loop(rest, current <> char, acc, in_quote)
    }
    
    // end of string
    Error(_) -> {
      case current {
        "" -> list.reverse(acc)
        _ -> list.reverse([current, ..acc])
      }
    }
  }
}

fn handle_command(args: List(String)) {
  case args {
    ["register", username] -> register_user(username)
    ["user", username] -> get_user_info(username)
    
    ["subreddit", name, desc] -> create_subreddit(name, desc)
    ["join", username, sub] -> join_subreddit(username, sub)
    ["leave", username, sub] -> leave_subreddit(username, sub)
    
    ["post", username, sub, title, content] -> create_post(username, sub, title, content)
    ["view_post", post_id] -> get_post_details(post_id)
    
    ["feed", username] -> get_feed(username)
    
    ["upvote", username, post_id] -> upvote_post(username, post_id)
    ["downvote", username, post_id] -> downvote_post(username, post_id)
    
    ["comment", username, post_id, content] -> create_comment(username, post_id, content, "")
    ["comment", username, post_id, content, parent_id] -> create_comment(username, post_id, content, parent_id)
    ["view_comment", comment_id] -> get_comment_details(comment_id)
    
    ["dm", from, to, content] -> send_dm(from, to, content)
    ["inbox", username, from] -> check_dms(username, from)
    
    ["help"] -> print_help()
    _ -> {
      io.println("Invalid command.")
      print_help()
    }
  }
}

fn register_user(username: String) {
  let body =
    json.object([#("username", json.string(username))])
    |> json.to_string

  send_post("/users", body)
}

fn create_subreddit(name: String, desc: String) {
  let body =
    json.object([
      #("name", json.string(name)),
      #("description", json.string(desc)),
    ])
    |> json.to_string

  send_post("/subreddits", body)
}

fn get_user_info(username: String) {
  send_get("/users/" <> username)
}

fn join_subreddit(username: String, sub: String) {
  let body =
    json.object([
      #("subreddit_name", json.string(sub)),
    ])
    |> json.to_string

  send_post("/users/" <> username <> "/subreddits/join", body)
}

fn leave_subreddit(username: String, sub: String) {
  let body = json.object([#("subreddit_name", json.string(sub))]) |> json.to_string
  send_post("/users/" <> username <> "/subreddits/leave", body)
}


fn create_post(username: String, sub: String, title: String, content: String) {
  let body =
    json.object([
      #("username", json.string(username)),
      #("subreddit_name", json.string(sub)),
      #("title", json.string(title)),
      #("content", json.string(content)),
    ])
    |> json.to_string

  send_post("/posts", body)
}

fn get_post_details(post_id: String) {
  send_get("/posts/" <> post_id)
}

fn upvote_post(username: String, post_id: String) {
  let body = json.object([#("username", json.string(username))]) |> json.to_string
  send_post("/posts/" <> post_id <> "/upvote", body)
}

fn downvote_post(username: String, post_id: String) {
  let body = json.object([#("username", json.string(username))]) |> json.to_string
  send_post("/posts/" <> post_id <> "/downvote", body)
}

fn get_feed(username: String) {
  send_get("/users/" <> username <> "/feed")
}

fn create_comment(username: String, post_id: String, content: String, parent_id: String) {
  let fields = [
    #("username", json.string(username)),
    #("post_id", json.string(post_id)),
    #("content", json.string(content))
  ]

  let final_fields = case parent_id {
    "" -> fields
    pid -> [#("parent_comment_id", json.string(pid)), ..fields]
  }

  let body = json.object(final_fields) |> json.to_string
  send_post("/comments", body)
}

fn get_comment_details(comment_id: String) {
  send_get("/comments/" <> comment_id)
}

fn send_dm(from: String, to: String, content: String) {
  let body =
    json.object([
      #("username", json.string(from)),
      #("to", json.string(to)),
      #("content", json.string(content)),
    ])
    |> json.to_string

  send_post("/messages", body)
}

fn check_dms(username: String, other_user: String) {
  send_get("/users/" <> username <> "/messages/" <> other_user)
}


fn send_post(path: String, json_body: String) {
  let assert Ok(req) = request.to(base_url <> path)
  
  let req = req
    |> request.set_method(http.Post)
    |> request.set_header("content-type", "application/json")
    |> request.set_body(json_body)

  handle_response(httpc.send(req))
}

fn send_get(path: String) {
  let assert Ok(req) = request.to(base_url <> path)
  handle_response(httpc.send(req))
}

fn handle_response(result: Result(response.Response(String), httpc.HttpError)) {
  case result {
    Ok(resp) -> {
      io.println("Status: " <> string.inspect(resp.status))
      io.println("Body: " <> resp.body)
    }
    Error(e) -> io.println("Failed to make request: " <> string.inspect(e))
  }
}

fn print_help() {
  io.println("Usage:")
  io.println("  register <username>")
  io.println("  user <username>")
  io.println("  subreddit <name> <desc>")
  io.println("  join <username> <subreddit>")
  io.println("  leave <username> <subreddit>")
  io.println("  post <username> <subreddit> <title> <content>")
  io.println("  view_post <post_id>")
  io.println("  upvote <username> <post_id>")
  io.println("  downvote <username> <post_id>")
  io.println("  comment <username> <post_id> <content> [parent_comment_id]")
  io.println("  view_comment <comment_id>")
  io.println("  feed <username>")
  io.println("  dm <from> <to> <content>")
  io.println("  inbox <username> <from_whom>")
  io.println("  exit")
}