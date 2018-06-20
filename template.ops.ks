@LAZYGLOBAL OFF.
{
  import("lib/diskio.ks").
  import("lib/text.ks").
  local mission is import("lib/mission.ks").
  local events is import("lib/events.ks").

  mission["loadMission"]("Missions/template.ks").

  mission["addEvent"]("fairings", events["deployFairings"]).
  mission["addEvent"]("panels", events["deployPanels"]).
  mission["addEvent"]("staging", events["checkStaging"], false).

  mission["runMission"]().
}
