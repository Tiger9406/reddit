// src/simulator.gleam

import gleam/io
import gleam/int
import gleam/float
import gleam/list
import gleam/erlang/process
import gleam/otp/actor
import gleam/option.{type Option, None, Some}
import types
import engine/engine_supervisor
import gleam/set.{type Set}

// ===== SIMULATOR CONFIGURATION =====

pub type SimulatorConfig {
    SimulatorConfig(
        num_users: Int,
        num_subreddits: Int,
        simulation_duration_ms: Int,
        zipf_exponent: Float,  // Typically 1.0 for classic Zipf
    )
}

pub type SimulatorState {
    SimulatorState(
        engine: process.Subject(types.EngineMessage),
        config: SimulatorConfig,
        subreddit_names: List(String),
        user_actors: List(process.Subject(UserSimulatorMessage)),
    )
}

// ===== USER SIMULATOR ACTOR =====

pub type UserSimulatorState {
    UserSimulatorState(
        username: String,
        engine: process.Subject(types.EngineMessage),
        joined_subreddits: List(String),
        is_online: Bool,
        action_count: Int,
        self_mailbox: Option(process.Subject(UserSimulatorMessage)),
        skew_factor: Float
    )
}

pub type UserSimulatorMessage {
    StartSimulation(available_subreddits: List(String), self_address_given: process.Subject(UserSimulatorMessage))
    PerformAction
    GoOffline
    GoOnline
    Stop
}

// ===== ZIPF DISTRIBUTION =====

// Generate Zipf-distributed subreddit popularity
// Rank 1 subreddit gets most subscribers, rank 2 gets half, etc.
fn calculate_zipf_subscribers(rank: Int, base_subscribers: Int, exponent: Float) -> Int {
    let rank_float = int.to_float(rank)
    let base_float = int.to_float(base_subscribers)
    case float.power(rank_float, exponent){
        Ok(val) ->{
            let result = base_float/. val
            float.truncate(result)
        }
        Error(_)->{
            io.println("float power operation cooked")
            0
        }
    }
}

// Generate subreddit names with Zipf-distributed popularity scores
fn generate_subreddits(num_subreddits: Int, base_subscribers: Int, exponent: Float) -> List(#(String, Int)) {
    list.range(1, num_subreddits) |> list.map(fn(rank) {
        let name = "subreddit_" <> int.to_string(rank)
        let target_subscribers = calculate_zipf_subscribers(rank, base_subscribers, exponent)
        #(name, target_subscribers)
    })
}

// ===== MAIN SIMULATOR FUNCTIONS =====

pub fn start_simulator(config: SimulatorConfig) -> process.Subject(types.EngineMessage) {
    io.println("=== Starting Reddit Simulator ===")
    io.println("Users: " <> int.to_string(config.num_users))
    io.println("Subreddits: " <> int.to_string(config.num_subreddits))
    
    // Start engine
    io.println("Starting engine...")
    let assert Ok(engine) = engine_supervisor.start()
    
    // Create subreddits with Zipf distribution
    io.println("Creating subreddits with Zipf distribution...")
    let subreddits = generate_subreddits(config.num_subreddits, config.num_users, config.zipf_exponent)
    
    subreddits |> list.each(fn(subreddit) {
        let #(name, expected_subs) = subreddit
        io.println("Creating " <> name <> " (target: " <> int.to_string(expected_subs) <> " subscribers)")
        process.send(engine, types.EngineUserCreateSubreddit(name, "A subreddit for " <> name))
    })
    
    // Create users
    io.println("Creating " <> int.to_string(config.num_users) <> " users...")
    let user_actors = list.range(1, config.num_users) |> list.map(fn(user_id) {
        let username = "user_" <> int.to_string(user_id)
        process.send(engine, types.EngineCreateUser(username))
        
        // Start user simulator actor
        let initial_state = UserSimulatorState(
            username: username,
            engine: engine,
            joined_subreddits: [],
            is_online: True,
            action_count: 0,
            self_mailbox: None,
            skew_factor: config.zipf_exponent
        )
        
        let assert Ok(actor) = actor.new(initial_state)
        |> actor.on_message(user_simulator_actor)
        |> actor.start()
        
        actor.data
    })
    
    // Give engine time to create everything
    process.sleep(100)
    
    // Start user simulations with Zipf-distributed subreddit joining
    io.println("Users joining subreddits (Zipf distribution)...")
    let subreddit_names = list.map(subreddits, fn(s) { s.0 })
    
    user_actors |> list.each(fn(user_actor) {
        process.send(user_actor, StartSimulation(subreddit_names, user_actor))
    })
    
    io.println("=== Simulation started! ===")
    
    engine
}

// ===== USER SIMULATOR ACTOR LOGIC =====

fn user_simulator_actor(
    state: UserSimulatorState,
    message: UserSimulatorMessage,
) -> actor.Next(UserSimulatorState, UserSimulatorMessage) {
    case message {
        StartSimulation(available_subreddits, self_address_given) -> {
            
            // Join subreddits with Zipf bias (more likely to join popular ones)
            let num_to_join = random_range(1, 5)  // Each user joins 1-5 subreddits
            let subreddits_to_join = select_subreddits_zipf(available_subreddits, num_to_join, state.skew_factor)
            
            subreddits_to_join |> list.each(fn(subreddit) {
                process.send(state.engine, types.EngineUserJoinSubreddit(state.username, subreddit))
            })
            
            let new_state = UserSimulatorState(..state, joined_subreddits: subreddits_to_join, self_mailbox: Some(self_address_given))
            
            let delay_ms = random_range(50, 500)
            process.send_after(self_address_given, delay_ms, PerformAction)
            
            actor.continue(new_state)
        }
        
        PerformAction -> {
            case state.is_online {
                False -> actor.continue(state)
                True -> {
                    // Randomly choose an action
                    let action = int.random(10)
                    
                    case action {
                        0 | 1 | 2 -> {
                            case state.joined_subreddits {
                                [] -> Nil
                                subreddits -> {
                                let subreddit = random_choice(subreddits)
                                let title = "Post by " <> state.username <> " #" <> int.to_string(state.action_count)
                                let content = "This is post content from " <> state.username
                                process.send(state.engine, types.EngineUserCreatePost(
                                    state.username,
                                    subreddit,
                                    title,
                                    content
                                ))
                                }
                            }
                        }
                        3 | 4 | 5 -> {
                            let post_id = int.to_string(random_range(1, 100))
                            process.send(state.engine, types.EngineUserLikesPost(state.username, post_id))
                        }
                        6 -> {
                            let post_id = int.to_string(random_range(1, 100))
                            process.send(state.engine, types.EngineUserDislikesPost(state.username, post_id))
                        }
                        7 | 8 -> {
                            let post_id = int.to_string(random_range(1, 100))
                            let content = "Comment from " <> state.username
                            process.send(state.engine, types.EngineUserCreateComment(
                                state.username,
                                post_id,
                                None,
                                content
                            ))
                        }
                        9 -> {
                            let other_user = "user_" <> int.to_string(random_range(1, 1000))
                            process.send(state.engine, types.EngineUserSendDM(
                                state.username,
                                other_user,
                                "Hello from " <> state.username
                            ))
                        }
                        _ -> Nil
                    }
                    
                    let new_state = UserSimulatorState(..state, action_count: state.action_count + 1)
                    
                    case state.self_mailbox{
                        Some(actor)->{
                            let delay_ms = random_range(50, 500)
                            process.send_after(actor, delay_ms, PerformAction)
                            Nil
                        }
                        None->{
                            io.println("error: no mailbox")
                        }
                    }
                    actor.continue(new_state)
                }
            }
        }
        
        GoOffline -> {
            io.println(state.username <> " went offline")
            actor.continue(UserSimulatorState(..state, is_online: False))
        }
        
        GoOnline -> {
            io.println(state.username <> " came online")
            actor.continue(UserSimulatorState(..state, is_online: True))
        }
        
        Stop -> {
            actor.stop()
        }
    }
}

// ===== HELPER FUNCTIONS =====

// Helper function to get a single biased index
fn get_biased_index(max_index: Int, skew_factor: Float) -> Int {
    // Generate Zipf-distributed index
    let r = float.random()
    let temp = 1.0 /. {r +. 0.01}
    
    case float.power(temp, 1.0 /. skew_factor) {
        Ok(rank_float) -> {
            let rank = float.round(rank_float)
            // Convert rank (1-based) to index (0-based)
            let index = rank - 1
            // Clamp to valid range
            int.min(int.max(index, 0), max_index)
        }
        Error(_) -> 0
    }
}

// We use a recursive helper function to build up a
// set of unique indices until we have `target_count`.
fn find_indices (max_index: Int, chosen: set.Set(Int), target_count: Int, skew_index: Float) -> Set(Int) {
    case set.size(chosen) >=target_count{
        True-> chosen
        False->find_indices(max_index, set.insert(chosen, get_biased_index(max_index, skew_index)), target_count, skew_index)
    }
}
// Selects a number of items from a list with a power-law (Zipf-like)
// bias, strongly preferring items at the beginning of the list.
// Returns a list of unique items.
pub fn select_subreddits_zipf(
    subreddits: List(String),
    count: Int,
    skew_factor
) -> List(String) {
    let len = list.length(subreddits)
    case len, count{
        0, 0->[]
        _, _->{
            // 1. Start with an empty set and find our target number of indices
            let indices = find_indices(len - 1, set.new(), int.min(count, len), skew_factor)

            // 2. Convert the set of indices into a list
            let index_list = set.to_list(indices)

            let selections = list.filter_map(index_list, fn(i) {
                // list.filter_map automatically takes the Ok(value)
                // from the Result and discards any Error(Nil).
                list.drop(subreddits, i)|>list.first
            })

            selections
        }
    }
}

fn random_choice(items: List(a)) -> a {
    let len = list.length(items)
    let index = random_range(0, len - 1)
    let assert Ok(item) = list.drop(items, index) |> list.first
    item
}

fn random_range(min: Int, max: Int) -> Int {
    let diff = int.random(max-min)
    min+diff
}

// ===== MAIN ENTRY POINT =====

pub fn run_simulation() -> Nil {
    let config = SimulatorConfig(
        num_users: 1000,
        num_subreddits: 100,
        simulation_duration_ms: 10000, 
        zipf_exponent: 2.0,
    )
    
    let engine = start_simulator(config)
    
    io.println("\n=== Simulation running for "<> int.to_string(config.simulation_duration_ms/1000)<>" seconds ===")
    process.sleep(config.simulation_duration_ms)

    process.send(engine, types.EngineGetAllComments)
    process.send(engine, types.EngineGetAllDMs)
    process.send(engine, types.EngineGetAllUsers)
    process.send(engine, types.EngineGetAllSubreddits)
    process.send(engine, types.EngineGetAllPosts)

    process.sleep(2000)
    
    io.println("\n=== Simulation complete ===")
}