// // src/simulator.gleam

// import gleam/io
// import gleam/int
// import gleam/float
// import gleam/list
// import gleam/erlang/process.{type Subject}
// import gleam/otp/actor
// import gleam/option.{type Option, None, Some}
// import types
// import engine/engine_supervisor
// import gleam/set.{type Set}
// import gleam/time/timestamp.{type Timestamp}

// pub type SimulatorConfig {
//     SimulatorConfig(
//         num_users: Int,
//         num_subreddits: Int,
//         simulation_duration_ms: Int,
//         zipf_exponent: Float,
//     )
// }

// pub type SimulatorState {
//     SimulatorState(
//         engine: Subject(types.EngineMessage),
//         config: SimulatorConfig,
//         subreddit_names: List(String),
//         user_actors: List(Subject(UserSimulatorMessage)),
//     )
// }

// pub type UserSimulatorState {
//     UserSimulatorState(
//         username: String,
//         engine: Subject(types.EngineMessage),
//         joined_subreddits: List(String),
//         is_online: Bool,
//         action_count: Int,
//         self_mailbox: Option(Subject(UserSimulatorMessage)),
//         skew_factor: Float,
//         metric_actor: Subject(MetricsMessage),
//         coordinator: Subject(CoordinatorMessage),
//         delay_time: Int
//     )
// }

// pub type UserSimulatorMessage {
//     Initialize(coordinator: Subject(CoordinatorMessage))
//     StartSimulation(available_subreddits: List(String), self_address_given: Subject(UserSimulatorMessage))
//     PerformAction
//     GoOffline
//     GoOnline
//     Stop
// }

// pub type PerformanceMetrics {
//     PerformanceMetrics(
//         start_time: Timestamp,
//         posts_created: Int,
//         comments_created: Int,
//         upvotes: Int,
//         downvotes: Int,
//         dms_sent: Int,
//         subreddit_joins: Int,
//         subreddit_leaves: Int,
//         total_actions: Int,
//     )
// }

// pub type MetricsMessage {
//     RecordPost
//     RecordComment
//     RecordUpvote
//     RecordDownvote
//     RecordDM
//     RecordSubredditJoin
//     RecordSubredditLeave
//     UpdateStartTime(new_start: Timestamp)
//     GetMetrics(reply_to: Subject(PerformanceMetrics))
// }

// pub type MetricsState {
//     MetricsState(
//         start_time: Timestamp,
//         posts: Int,
//         comments: Int,
//         upvotes: Int,
//         downvotes: Int,
//         dms: Int,
//         joins: Int,
//         leaves: Int,
//     )
// }

// pub type CoordinatorMessage {
//     UserReady(username: String)
//     AllUsersReady(reply_to: Subject(Timestamp))
// }

// pub type CoordinatorState {
//     CoordinatorState(
//         ready_users: Set(String),
//         total_users: Int,
//         waiting_for: Option(Subject(Timestamp))
//     )
// }

// // zipf
// fn calculate_zipf_subscribers(rank: Int, base_subscribers: Int, exponent: Float) -> Int {
//     let rank_float = int.to_float(rank)
//     let base_float = int.to_float(base_subscribers)
//     case float.power(rank_float, exponent){
//         Ok(val) ->{
//             let result = base_float/. val
//             float.truncate(result)
//         }
//         Error(_)->{
//             io.println("float power operation cooked")
//             0
//         }
//     }
// }

// fn generate_subreddits(num_subreddits: Int, base_subscribers: Int, exponent: Float) -> List(#(String, Int)) {
//     list.range(1, num_subreddits) |> list.map(fn(rank) {
//         let name = "subreddit_" <> int.to_string(rank)
//         let target_subscribers = calculate_zipf_subscribers(rank, base_subscribers, exponent)
//         #(name, target_subscribers)
//     })
// }

// fn coordinator_actor(
//     state: CoordinatorState,
//     message: CoordinatorMessage,
// ) -> actor.Next(CoordinatorState, CoordinatorMessage) {
//     case message {
//         UserReady(username) -> {
//             let new_ready = set.insert(state.ready_users, username)
//             let ready_count = set.size(new_ready)
            
//             // Check if all users are ready
//             case ready_count == state.total_users, state.waiting_for {
//                 True, Some(reply_to) -> {
//                     io.println("All " <> int.to_string(state.total_users) <> " users ready!")
//                     let start_time = timestamp.system_time()
//                     process.send(reply_to, start_time)
//                     actor.continue(CoordinatorState(..state, ready_users: new_ready))
//                 }
//                 True, None -> {
//                     actor.continue(CoordinatorState(..state, ready_users: new_ready))
//                 }
//                 False, _ -> {
//                     case ready_count % 10000 == 0 {
//                         True -> io.println("Users ready: " <> int.to_string(ready_count) <> "/" <> int.to_string(state.total_users))
//                         False -> Nil
//                     }
//                     actor.continue(CoordinatorState(..state, ready_users: new_ready))
//                 }
//             }
//         }
//         AllUsersReady(reply_to) -> {
//             case set.size(state.ready_users) == state.total_users {
//                 True -> {
//                     let start_time = timestamp.system_time()
//                     process.send(reply_to, start_time)
//                     actor.continue(state)
//                 }
//                 False -> {
//                     actor.continue(CoordinatorState(..state, waiting_for: Some(reply_to)))
//                 }
//             }
//         }
//     }
// }

// fn metrics_actor(
//     state: MetricsState,
//     message: MetricsMessage,
// ) -> actor.Next(MetricsState, MetricsMessage) {
//     case message {
//         RecordPost -> actor.continue(MetricsState(..state, posts: state.posts + 1))
//         RecordComment -> actor.continue(MetricsState(..state, comments: state.comments + 1))
//         RecordUpvote -> actor.continue(MetricsState(..state, upvotes: state.upvotes + 1))
//         RecordDownvote -> actor.continue(MetricsState(..state, downvotes: state.downvotes + 1))
//         RecordDM -> actor.continue(MetricsState(..state, dms: state.dms + 1))
//         RecordSubredditJoin -> actor.continue(MetricsState(..state, joins: state.joins + 1))
//         RecordSubredditLeave -> actor.continue(MetricsState(..state, leaves: state.leaves + 1))
        
//         UpdateStartTime(new_start) -> {
//             actor.continue(MetricsState(..state, start_time: new_start))
//         }
        
//         GetMetrics(reply_to) -> {
//             let total = state.posts + state.comments + state.upvotes +
//                        state.downvotes + state.dms + state.joins + state.leaves
//             let metrics = PerformanceMetrics(
//                 start_time: state.start_time,
//                 posts_created: state.posts,
//                 comments_created: state.comments,
//                 upvotes: state.upvotes,
//                 downvotes: state.downvotes,
//                 dms_sent: state.dms,
//                 subreddit_joins: state.joins,
//                 subreddit_leaves: state.leaves,
//                 total_actions: total,
//             )
//             process.send(reply_to, metrics)
//             actor.continue(state)
//         }
//     }
// }

// fn calculate_user_activity_delay(rank: Int, max_rank_f: Float, min_delay_f: Float, max_delay_f: Float, exponent: Float) -> Int {
//     case rank <=1 {
//         True-> float.round(min_delay_f)
//         False->{
//             let rank_f = int.to_float(rank)
//             case rank_f >=. max_delay_f{
//                 True-> float.round(max_delay_f)
//                 False->{
//                     let delay_range = max_delay_f -. min_delay_f

//                     let normalized_rank = {rank_f -. 1.0} /. {max_rank_f -. 1.0}

//                     let assert Ok(curved_norm) = float.power(normalized_rank, exponent)
//                     let calculated_delay = min_delay_f +. curved_norm *. delay_range

//                     float.round(calculated_delay)
//                 }
//             }
//         }
//     }
// }

// pub fn start_simulator(config: SimulatorConfig) -> #(process.Subject(types.EngineMessage), process.Subject(MetricsMessage), Timestamp) {
//     io.println("=== Starting Reddit Simulator ===")
//     io.println("Users: " <> int.to_string(config.num_users))
//     io.println("Subreddits: " <> int.to_string(config.num_subreddits))
    
//     // Start coordinator
//     let coordinator_state = CoordinatorState(
//         ready_users: set.new(),
//         total_users: config.num_users,
//         waiting_for: None,
//     )
//     let assert Ok(coordinator) = actor.new(coordinator_state)
//         |> actor.on_message(coordinator_actor)
//         |> actor.start()
    
//     // Start metrics actor (but DON'T set start_time yet)
//     let placeholder_time = timestamp.system_time()
//     let metrics_state = MetricsState(
//         start_time: placeholder_time,
//         posts: 0,
//         comments: 0,
//         upvotes: 0,
//         downvotes: 0,
//         dms: 0,
//         joins: 0,
//         leaves: 0,
//     )
//     let assert Ok(metrics) = actor.new(metrics_state)
//         |> actor.on_message(metrics_actor)
//         |> actor.start()
    
//     let metric_subject = metrics.data
    
//     // Start engine
//     io.println("Starting engine...")
//     let assert Ok(engine) = engine_supervisor.start()
    
//     // Create subreddits
//     io.println("Creating subreddits with Zipf distribution...")
//     let subreddits = generate_subreddits(config.num_subreddits, config.num_users, config.zipf_exponent)
//     subreddits |> list.each(fn(subreddit) {
//         let #(name, _) = subreddit
//         process.send(engine, types.EngineUserCreateSubreddit(name, "A subreddit for " <> name))
//     })
    
//     // Create users
//     io.println("Creating " <> int.to_string(config.num_users) <> " users...")
//     let num_users_f=int.to_float(config.num_users)

//     let user_actors = list.range(1, config.num_users) |> list.map(fn(user_id) {
//         let username = "user_" <> int.to_string(user_id)
//         process.send(engine, types.EngineCreateUser(username))
        
//         let initial_state = UserSimulatorState(
//             username: username,
//             engine: engine,
//             joined_subreddits: [],
//             is_online: True,
//             action_count: 0,
//             self_mailbox: None,
//             skew_factor: config.zipf_exponent,
//             metric_actor: metric_subject,
//             coordinator: coordinator.data,
//             delay_time: calculate_user_activity_delay(user_id, num_users_f, 500.0, 5000.0, config.zipf_exponent)
//         )
//         let assert Ok(actor) = actor.new(initial_state)
//             |> actor.on_message(user_simulator_actor)
//             |> actor.start()
        
//         // Tell each user to initialize
//         process.send(actor.data, Initialize(coordinator.data))
        
//         actor.data
//     })
    
//     io.println("Waiting for all users to be ready...")
    
//     // Wait for all users to be ready and get the true start time
//     let ready_subject = process.new_subject()
//     process.send(coordinator.data, AllUsersReady(ready_subject))
//     let assert Ok(true_start_time) = process.receive(ready_subject, 30000) // 30 second timeout
    
//     // Update metrics with true start time
//     process.send(metric_subject, UpdateStartTime(true_start_time))
    
//     // NOW start user simulations
//     io.println("Starting user simulations (Zipf distribution)...")
//     let subreddit_names = list.map(subreddits, fn(s) { s.0 })
//     user_actors |> list.each(fn(user_actor) {
//         process.send(user_actor, StartSimulation(subreddit_names, user_actor))
//     })
    
//     io.println("=== Simulation started! ===")
//     #(engine, metrics.data, true_start_time)
// }

// fn user_simulator_actor(
//     state: UserSimulatorState,
//     message: UserSimulatorMessage,
// ) -> actor.Next(UserSimulatorState, UserSimulatorMessage) {
//     case message {
//         Initialize(coordinator) -> {
//             process.send(coordinator, UserReady(state.username))
//             let new_state = UserSimulatorState(..state, coordinator: coordinator)
//             actor.continue(new_state)
//         }
        
//         StartSimulation(available_subreddits, self_address_given) -> {
//             let num_to_join = random_range(1, 5)  // Each user joins 1-5 subreddits
//             let subreddits_to_join = select_subreddits_zipf(available_subreddits, num_to_join, state.skew_factor)
//             subreddits_to_join |> list.each(fn(subreddit) {
//                 process.send(state.engine, types.EngineUserJoinSubreddit(state.username, subreddit))
//                 process.send(state.metric_actor, RecordSubredditJoin)
//             })
//             let new_state = UserSimulatorState(..state, joined_subreddits: subreddits_to_join, self_mailbox: Some(self_address_given))
//             process.send_after(self_address_given, state.delay_time, PerformAction)
//             actor.continue(new_state)
//         }
        
//         PerformAction -> {
//             case state.is_online {
//                 False -> actor.continue(state)
//                 True -> {
//                     // Randomly choose an action
//                     let action = int.random(20)
//                     case action {
//                         0 -> {
//                             case state.joined_subreddits {
//                                 [] -> Nil
//                                 subreddits -> {
//                                     let subreddit = random_choice(subreddits)
//                                     let title = "Post by " <> state.username <> " #" <> int.to_string(state.action_count)
//                                     let content = "This is post content from " <> state.username
//                                     process.send(state.engine, types.EngineUserCreatePost(
//                                         state.username,
//                                         subreddit,
//                                         title,
//                                         content
//                                     ))
//                                     process.send(state.metric_actor, RecordPost)
//                                 }
//                             }
//                         }
//                         1 | 2 | 3 |4  -> {
//                             let post_id = int.to_string(random_range(1, 100))
//                             process.send(state.engine, types.EngineUserLikesPost(state.username, post_id))
//                             process.send(state.metric_actor, RecordUpvote)
//                         }
//                         5|6|7|8 -> {
//                             let post_id = int.to_string(random_range(1, 100))
//                             process.send(state.engine, types.EngineUserDislikesPost(state.username, post_id))
//                             process.send(state.metric_actor, RecordDownvote)
//                         }
//                         9|10|11|12  -> {
//                             let post_id = int.to_string(random_range(1, 100))
//                             let content = "Comment from " <> state.username
//                             process.send(state.engine, types.EngineUserCreateComment(
//                                 state.username,
//                                 post_id,
//                                 None,
//                                 content
//                             ))
//                             process.send(state.metric_actor, RecordComment)
//                         }
//                         13|14|15|16|17|18 -> {
//                             let other_user = "user_" <> int.to_string(random_range(1, 1000))
//                             process.send(state.engine, types.EngineUserSendDM(
//                                 state.username,
//                                 other_user,
//                                 "Hello from " <> state.username
//                             ))
//                             process.send(state.metric_actor, RecordDM)
//                         }
//                         _ -> Nil
//                     }
//                     let new_state = UserSimulatorState(..state, action_count: state.action_count + 1)
//                     case state.self_mailbox{
//                         Some(actor)->{
//                             process.send_after(actor, state.delay_time, PerformAction)
//                             Nil
//                         }
//                         None->{
//                             io.println("error: no mailbox")
//                         }
//                     }
//                     actor.continue(new_state)
//                 }
//             }
//         }
        
//         GoOffline -> {
//             io.println(state.username <> " went offline")
//             actor.continue(UserSimulatorState(..state, is_online: False))
//         }
        
//         GoOnline -> {
//             io.println(state.username <> " came online")
//             actor.continue(UserSimulatorState(..state, is_online: True))
//         }
        
//         Stop -> {
//             actor.stop()
//         }
//     }
// }

// // Helper function to get a single biased index
// fn get_biased_index(max_index: Int, skew_factor: Float) -> Int {
//     // Generate Zipf-distributed index
//     let r = float.random()
//     let temp = 1.0 /. {r +. 0.01}
//     case float.power(temp, 1.0 /. skew_factor) {
//         Ok(rank_float) -> {
//             let rank = float.round(rank_float)
//             let index = rank - 1
//             int.min(int.max(index, 0), max_index)
//         }
//         Error(_) -> 0
//     }
// }

// // set of unique indices recursively
// fn find_indices (max_index: Int, chosen: set.Set(Int), target_count: Int, skew_index: Float) -> Set(Int) {
//     case set.size(chosen) >= target_count{
//         True -> chosen
//         False -> find_indices(max_index, set.insert(chosen, get_biased_index(max_index, skew_index)), target_count, skew_index)
//     }
// }

// // return list of unique subreddits following zipf
// pub fn select_subreddits_zipf(
//     subreddits: List(String),
//     count: Int,
//     skew_factor
// ) -> List(String) {
//     let len = list.length(subreddits)
//     case len, count{
//         0, 0 -> []
//         _, _ -> {
//             let indices = find_indices(len - 1, set.new(), int.min(count, len), skew_factor)
//             let index_list = set.to_list(indices)
            
//             let selections = list.filter_map(index_list, fn(i) {
//                 list.drop(subreddits, i)|>list.first
//             })
            
//             selections
//         }
//     }
// }

// fn random_choice(items: List(a)) -> a {
//     let len = list.length(items)
//     let index = random_range(0, len - 1)
//     let assert Ok(item) = list.drop(items, index) |> list.first
//     item
// }

// fn random_range(min: Int, max: Int) -> Int {
//     let diff = int.random(max-min)
//     min+diff
// }

// fn display_metrics(metrics: PerformanceMetrics, duration_ms: Int) -> Nil {
//     let duration_sec = int.to_float(duration_ms) /. 1000.0
//     let actions_per_sec = int.to_float(metrics.total_actions) /. duration_sec
//     io.println("\n" <> "=" |> list.repeat(30) |> list.fold("", fn(acc, s) { acc <> s }))
//     io.println("PERFORMANCE METRICS")
//     io.println("=" |> list.repeat(30) |> list.fold("", fn(acc, s) { acc <> s }))
//     io.println("Duration: " <> float.to_string(duration_sec) <> " seconds")
//     io.println("")
//     io.println("Total Actions: " <> int.to_string(metrics.total_actions))
//     io.println("  Posts Created: " <> int.to_string(metrics.posts_created))
//     io.println("  Comments Created: " <> int.to_string(metrics.comments_created))
//     io.println("  Upvotes: " <> int.to_string(metrics.upvotes))
//     io.println("  Downvotes: " <> int.to_string(metrics.downvotes))
//     io.println("  DMs Sent: " <> int.to_string(metrics.dms_sent))
//     io.println("  Subreddit Joins: " <> int.to_string(metrics.subreddit_joins))
//     io.println("  Subreddit Leaves: " <> int.to_string(metrics.subreddit_leaves))
//     io.println("")
//     io.println("Throughput: " <> float.to_string(actions_per_sec) <> " actions/second")
//     io.println("=" |> list.repeat(30) |> list.fold("", fn(acc, s) { acc <> s }) <> "\n")
// }

// pub fn run_simulation() -> Nil {
//     let config = SimulatorConfig(
//         num_users: 10000,
//         num_subreddits: 500,
//         simulation_duration_ms: 20000,
//         zipf_exponent: 2.0,
//     )
    
//     let #(engine, metrics_actor, _start_time) = start_simulator(config)
    
//     io.println("\n=== Simulation running for " <> int.to_string(config.simulation_duration_ms/1000) <> " seconds ===")
//     process.sleep(config.simulation_duration_ms)
    
//     let wait_time = 10000  // 10 seconds
    
//     let metrics_subject = process.new_subject()
//     process.send(metrics_actor, GetMetrics(metrics_subject))
//     let assert Ok(metrics) = process.receive(metrics_subject, wait_time)
    
//     process.send(engine, types.EngineGetAllComments)
//     process.sleep(1000)
//     process.send(engine, types.EngineGetAllDMs)
//     process.sleep(1000)
//     process.send(engine, types.EngineGetAllUsers)
//     process.sleep(1000)
//     process.send(engine, types.EngineGetAllSubreddits)
//     process.sleep(1000)
//     process.send(engine, types.EngineGetAllPosts)
//     process.sleep(1000)
    
//     // Display metrics
//     display_metrics(metrics, config.simulation_duration_ms)
//     process.sleep(2000)
//     io.println("\n=== Simulation complete ===")
// }

// pub fn main() -> Nil {
//     run_simulation()
// }


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