
# Reddit Engine Clone with Simulator

## Architecture

### Actor-Based Design
- **Separate Processes**: Engine and clients run in independent actor processes
- **Manager Pattern**: Each domain has a dedicated manager actor coordinating multiple entity actors
- **Asynchronous Message Passing**: All communication via message passing between actors

### Core Managers

| Manager | Responsibilities | Storage |
|---------|-----------------|---------|
| **UserManager** | User registration & karma tracking | `Dict<Username, UserActor>` |
| **SubredditManager** | Subreddit creation & subscriptions | `Dict<SubredditName, SubredditActor>` |
| **PostManager** | Post creation & voting | `Dict<PostId, PostActor>` |
| **CommentManager** | Hierarchical comments & voting | `Dict<CommentId, CommentActor>` |
| **DMManager** | Direct messaging between users | `Dict<ConversationId, DMActor>` |

## Features Implemented

**User Management**
- Account registration
- Karma computation from upvotes/downvotes

**Subreddit Operations**
- Create subreddits
- Join/leave subreddits
- Subscriber tracking

**Content Creation**
- Text posts in subreddits
- Hierarchical comments (replies to comments)
- Upvote/downvote system

**Social Features**
- Direct messaging
- User feed from subscribed subreddits

**Simulation**
- Zipf distribution for subreddit popularity
- 1000+ concurrent user simulation
- Realistic action patterns (posting, commenting, voting, messaging)

## Performance

Current metrics with 1000 users over 10 seconds:

```
Total Actions: ~39,000
Throughput: ~3,900 actions/second
Posts Created: ~11,000
Comments Created: ~7,500
Upvotes: ~11,000
Downvotes: ~3,700
DMs Sent: ~3,700
```

### Zipf Distribution Verification

Subreddit subscribers follow Zipf's law (exponent = 2.0):

| Rank | Subreddit | Subscribers |
|------|-----------|-------------|
| 1 | subreddit_1 | 877 |
| 2 | subreddit_2 | 728 |
| 3 | subreddit_3 | 416 |
| 4 | subreddit_4 | 216 |
| 5 | subreddit_5 | 109 |

## Running the Simulation

```bash
gleam run reddit.gleam
```

### Configuration

Edit `src/reddit.gleam`:

```gleam
let config = SimulatorConfig(
    num_users: 10000,
    num_subreddits: 200,
    simulation_duration_ms: 10000,
    zipf_exponent: 2.0,
)
```

## Project Structure

```
src/
├── engine/
│   ├── engine_supervisor.gleam  
│   └── engine_receive.gleam   
├── user/
│   ├── user_manager.gleam    
│   └── user_actor.gleam    
├── subreddit/
│   ├── subreddit_manager.gleam 
│   └── subreddit_actor.gleam
├── post/
│   ├── post_manager.gleam
│   └── post_actor.gleam
├── comment/
│   ├── comment_manager.gleam 
│   └── comment_actor.gleam
├── messaging/
│   ├── dm_manager.gleam
│   └── dm_actor.gleam
├── reddit.gleam                #entry point
└── types.gleam  
```

## basic stats

- **Concurrent Users**: Currently tested with 10,000 users
- **Action Rate**: ~6,000 actions/second sustained throughput
- **Actor Overhead**: Each entity is lightweight; system can handle 80,000+ concurrent actors