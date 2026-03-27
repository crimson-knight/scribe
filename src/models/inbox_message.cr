require "grant"

class Scribe::Models::InboxMessage < Grant::Base
  connection primary
  table inbox_messages

  column id : Int64, primary: true
  column thread_id : Int64         # FK to inbox_threads
  column message_uuid : String     # UUID
  column role : String             # "user" or "assistant"
  column content : String
  column processing_job_id : Int64? # links to CLI execution
  timestamps
end
