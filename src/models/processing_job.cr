require "grant"

class Scribe::Models::ProcessingJob < Grant::Base
  connection primary
  table processing_jobs

  column id : Int64, primary: true
  column job_type : String                # "transcription", "ai_processing"
  column input_path : String?
  column output_path : String?
  column current_status : String          # "pending", "running", "completed", "failed", "cancelled"
  column error_message : String?
  column started_at : Time?
  column completed_at : Time?
  timestamps
end
