require "grant"

class Scribe::Models::ApplicationSetting < Grant::Base
  connection primary
  table application_settings

  column id : Int64, primary: true
  column key : String
  column value : String
  timestamps
end
