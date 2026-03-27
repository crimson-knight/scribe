require "grant"

class Scribe::Models::InboxThread < Grant::Base
  connection primary
  table inbox_threads

  column id : Int64, primary: true
  column thread_uuid : String       # UUID for file naming
  column title : String
  column agent_id : String          # which agent handles this (default: "default")
  column current_status : String    # "active", "processing", "completed", "failed", "archived"
  column unread : Int32             # 0 or 1 (SQLite bool)
  column file_path : String         # path to .md thread file
  timestamps
end
