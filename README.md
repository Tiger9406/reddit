# reddit

To do
Make reddit backend engine via otp

## Features:
### User Management
- Register new user accounts
- Track user karma (sum of upvotes/downvotes on posts and comments)

### Subreddit Management
- Create subreddit
- Join / Leave subreddit
- Maintain list of members and post index

### Posts & Comments
- Create text posts in subreddit
- Comment on posts (hierarchical threads)
- Retrieve comments tree for a given post

### Voting System
- Upvote / Downvote posts and comments
- Update post score and author karma accordingly
- Enforce one vote per user per target

### Feeds
- Retrieve user feed (recent or top posts from subscribed subreddits)

### Direct Messages
- Send DM between users
- View message threads and reply


## Actors to imlement
- EngineSupervisor; starts subactors
- UserRegister: register new users, spawn user actors
- Countless UserActor (simulation side): tracks self karma & actions: post comment vote DM join & leave subreddit
- SubredditManagerSupervisor: supervises subreddit managers & spawns/deletes them
- SubredditManager: 1 per subreddit; owns subreddit metadata like name, members, post ID; receives join.leave requests, routes posts/comments/votes to PostActors
- PostManagerSupervisor: 1 per subreddit; supervises postActors for a subreddit
- PostActor: 1 per post; stores post content, author, score, and list of comment IDs. Handles upvotes & downvotes & sends to user actors when requested for karma from this post
- CommentActor: 1 per comment thread or one per set amount of comments; hierarchical comments for a single post
- DMActor: routes dms between users; 1 for each conversation & stores msg history


### Client side: 
- Simulator Supervisor
- actor that has connect to engine actor; no persistent information
- Distribution stuff to worry about later