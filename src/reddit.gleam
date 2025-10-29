import gleam/io
import gleam/erlang/process
import engine_supervisor
import types

pub fn main() -> Nil {
		io.println("Starting Reddit Engine Test...")
		
		// Start engine
		let assert Ok(engine) = engine_supervisor.start()
		
		// Get user manager (you'll need to add this helper or use direct process.call)
		let reply_subject = process.new_subject()
		process.send(engine, types.EngineGetUserManager(reply_subject))

		
		io.println("Basic test complete!")
}