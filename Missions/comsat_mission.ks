
{

  local curr_mission is lex(
    "sequence", list(
      "preflight", preflight@,
      "launch", launch@,
      "ascent", ascent@,
      "enable_antennae", enable_antennae@,
      "circularize", circularize@,
      "transfer", transfer@,
      "final_circ", circularize@,
      "end_launch", end_launch@
    ),
    "events", lex()
  ).

  global comsat_mission is {
    parameter TARGET_ALTITUDE is 100000.
    parameter TARGET_HEADING is 90.
    parameter FINAL_ALTITUDE is 550000.
    set curr_mission["target_altitude"] to TARGET_ALTITUDE.
    set curr_mission["target_heading"] to TARGET_HEADING.
    set curr_mission["final_altitude"] to FINAL_ALTITUDE.
    return curr_mission.
  }.

  function findNameIndex {
    parameter mission.
    local baseName is ship:name.
    local myVer is 1.
    list targets in shipList.
    for currShip in shipList {
      from {local ndx is myVer.} until ndx >= 4 step {set ndx to ndx + 1.} do {
        if (baseName + " " + ndx = currShip:name) {
          if (ndx >= 4) {
            return false.
          }
          set myVer to ndx + 1.
          break.
        }
      }
    }
    return myVer.
  }

  function preflight {
    parameter mission.

    // Set comsat name!
    local myIndex is findNameIndex(mission).
    if(not myIndex) {
      shutdown.
    }
    mission:add("control", ship:name + " " + max((myIndex - 1), 1)).
    mission:add("SRBs", stage:solidfuel > 1).
    set ship:name to ship:name + " " + myIndex.

    set ship:control:pilotmainthrottle to 0.
    output("Launch parameters: " + curr_mission["target_heading"] + ":" + curr_mission["target_altitude"] + ":" + curr_mission["final_altitude"], true).
    if launcher["launch"](curr_mission["target_heading"], curr_mission["target_altitude"], curr_mission["final_altitude"]) {
      launcher["start_countdown"](5).
      mission["next"]().
    } else {
      output("Unable to launch, mission terminated.", true).
      mission["terminate"]().
    }
  }

    function end_launch {
      parameter mission.
      mission["next"]().
    }

    function launch {
      parameter mission.
      if launcher["countdown"]() <= 0 {
        mission["add_event"]("staging", event_lib["staging"]).
        mission["next"]().
      }
    }

    function ascent {
      parameter mission.
      if launcher["ascent_complete"]() {
          mission["next"]().
        }
    }

    function circularize {
      parameter mission.
      if curr_mission:haskey("circ") {
        if launcher["circularized"]() {
          curr_mission:remove("circ").
          mission["next"]().
        }
      } else {
        launcher["circularize"]().
        set curr_mission["circ"] to true.
      }
    }

    function transfer {
      parameter mission.
      if launcher["transfer_complete"]()
        mission["next"]().
    }

    function enable_antennae {
      parameter mission.

      mission["next"]().
    }

  }
