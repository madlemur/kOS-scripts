{
  local launch_geo is import("launch_geo.ks").
  local launcher is lex(
    "version", "0.1.0",
    "countdown", countdown@:bind(-1),
    "start_countdown", countdown@,
    "launch", launch@,
    "ascent_complete", ascent_complete@,
    "transfer_complete", transfer_complete@,
    "circularize", circularize@,
    "circularized", circularize@,
    "launchtime", launchtime@,
    // Data points
    "count", -1,
    "last_count", 0,
    "transferring", false,
    "ascending", false
  ).

  function countdown {
    parameter count.
    if count < 0 {
      local i is time:seconds - launcher["launchDetails"][1].
      if time:seconds > launcher["last_count"] + 1.0 {
        set launcher["last_count"] to time:seconds.
        if i >= 0
          hudtext( "T minus " + i + "s" , 1, 1, 25, white, true).
        set launcher["count"] to i.
        return i.
      }
      return launcher["count"].
    }
    set launcher["last_count"] to time:seconds.
    set launcher["count"] to time:seconds - launcher["launchDetails"][1].
    hudtext( "T minus " + launcher["count"] + "s" , 1, 1, 25, white, true).
    return count.
  }

  function launch {
    parameter first_dest_ap. // first destination apoapsis.
    parameter second_dest_ap is -1. // second destination apoapsis.
    parameter angle_inclination is 0. // angle of inclination.
    parameter long_ascending is 0. // longitude of ascending node.

    if second_dest_ap < 0 { set second_dest_ap to first_dest_ap. }

    if first_dest_ap < (1.05 * body:atm:height) {
      output("Initial destination orbit must be above " + (1.05 * body:atm:height)/1000 + "km!", true).
      set throttle to 0.
      return false.
    }

    set launcher["launch_params"] to lex (
      "first_dest_ap", first_dest_ap,
      "second_dest_ap", second_dest_ap,
      "angle_inclination", angle_inclination,
      "long_ascending", long_ascending
    ).
    set launcher["ascending"] to false.
    set launcher["transferring"] to false.

    set launcher["launchDetails"] to launch_geo["calcLaunchDetails"](first_dest_ap, angle_inclination, long_ascending).

    // For all atmo launches with fins it helps to teach it that the fins help
    // torque, which it fails to realize:
    set pitch to 0.
    lock steering to heading(launch_geo["azimuth"](launcher["launch_params"]["angle_inclination"]), 90 + pitch).
    set tmoid to 1.
    set throttle to tmoid.

    return true.
  }

  function ascent_complete {
    if ship:apoapsis >= launcher["launch_params"]["first_dest_ap"] * 0.98 {
      set throttle to max(0, (launcher["launch_params"]["first_dest_ap"] - ship:apoapsis) / 2000).
      if eta_ap_with_neg() < 10 {
        set throttle to 0.
        return true.
      }
    } else if launcher["ascending"] {
      set salt to ship:altitude.
      set tta to eta:apoapsis.
      set pitch to -sqrt(0.1705 * salt) + 5.
      set teta to (-1 * pitch) + tgain * (pitch + 90).
      set pitch to max(-90, pitch).
      set tmoid to max(-1/(1+5^(min(teta - tta, 27.5632997166971552428868)))+1, 0.15).
      set throttle to tmoid.
    } else if ship:airspeed > 75 {
      output("Ascending to " + launcher["launch_params"]["first_dest_ap"], true).
      set twr to available_twr().
      set tgain to 0.1 - (0.1005 / max(twr, 0.00001)).
      output("Steering locked to gravity turn", true).
      set launcher["ascending"] to true.
    }
    if ship:apoapsis > launcher["launch_params"]["first_dest_ap"] * 0.85 and altitude > ship:apoapsis * 0.90 {
      return true.
    }
    return false.
  }

  function transfer_complete {
    if launcher["launch_params"]["second_dest_ap"] < 0 {
      return true.
    }
    if ship:apoapsis < launcher["launch_params"]["second_dest_ap"] {
      set throttle to max((launcher["launch_params"]["second_dest_ap"] - ship:apoapsis), 0) / 2000.
      return false.
    }
    set throttle to 0.
    return eta:apoapsis < 10.
  }

  function east_for {
    parameter ves.

    return vcrs(ves:up:vector, ves:north:vector).
  }
  // Return eta:apoapsis but with times behind you
  // rendered as negative numbers in the past:
  function eta_ap_with_neg {
    local ret_val is eta:apoapsis.
    if ret_val > ship:obt:period / 2 {
      set ret_val to ret_val - ship:obt:period.
    }
    return ret_val.
  }

  function compass_of_vel {
    local pointing is ship:velocity:orbit.
    local east is east_for(ship).

    local trig_x is vdot(ship:north:vector, pointing).
    local trig_y is vdot(east, pointing).

    local result is arctan2(trig_y, trig_x).

    if result < 0 {
      return 360 + result.
    } else {
      return result.
    }
  }

	function circ_thrott {
		if abs(steeringmanager:yawerror) < 2 and
			 abs(steeringmanager:pitcherror) < 2 and
			 abs(steeringmanager:rollerror) < 2 {
				 return 0.02 + (30*ship:obt:eccentricity).
		} else {
			return 0.
		}
	}

	function circularize {
    if (ship:obt:trueanomaly < 90 or ship:obt:trueanomaly > 270) {
      unlock steering.
      unlock throttle.
      set throttle to 0.
      return true.
    } else {
      set throttle to circ_thrott().
      set steering to heading(launch_geo["azimuth"](launcher["launch_params"]["angle_inclination"]), -(eta_ap_with_neg()/3)).
      return false.
    }
  }

  function available_twr {
  	local g is body:mu / (ship:altitude + body:radius)^2.
  	return ship:maxthrust / (body:mu / (ship:altitude + body:radius)^2) / ship:mass.
  }

  function launchtime {
    LOCAL lat IS SHIP:LATITUDE.
    LOCAL eclipticNormal is 0.
    if HASTARGET and TARGET:HASSUFFIX("BODY") AND TARGET:BODY = SHIP:BODY {
       set eclipticNormal to VCRS(TARGET:OBT:VELOCITY:ORBIT,TARGET:BODY:POSITION-TARGET:POSITION):NORMALIZED.
    } else if launcher["launch_params"]["long_ascending"] > 0 and not launcher["launch_params"]["angle_inclination"] = 0 {
      LOCAL KPM is ANGLEAXIS(-body:rotationangle,body:up:vector) * (body:GEOPOSITIONLATLNG(0,0):position - body:position).
      LOCAL InclNorm is ANGLEAXIS(launcher["launch_params"]["angle_inclination"], KPM) * BODY:UP:vector.
      LOCAL angleNeeded is ANGLEAXIS(launcher["launch_params"]["long_ascending"], BODY:UP:vector) * InclNorm.
      set eclipticNormal to angleNeeded:NORMALIZED.
    } else {
      return -1.
    }
    LOCAL planetNormal IS HEADING(0,lat):VECTOR.
    LOCAL bodyInc IS VANG(planetNormal, eclipticNormal).
    LOCAL beta IS ARCCOS(MAX(-1,MIN(1,COS(bodyInc) * SIN(lat) / SIN(bodyInc)))).
    LOCAL intersectdir IS VCRS(planetNormal, eclipticNormal):NORMALIZED.
    LOCAL intersectpos IS -VXCL(planetNormal, eclipticNormal):NORMALIZED.
    LOCAL launchtimedir IS (intersectdir * SIN(beta) + intersectpos * COS(beta)) * COS(lat) + SIN(lat) * planetNormal.
    LOCAL launchETA IS VANG(launchtimedir, SHIP:POSITION - BODY:POSITION) / 360 * BODY:ROTATIONPERIOD.
    if VCRS(launchtimedir, SHIP:POSITION - BODY:POSITION)*planetNormal < 0 {
        SET launchETA TO BODY:ROTATIONPERIOD - launchETA.
    }
    until launchETA >= 0 {
      set launchETA to launchETA + body:rotationperiod.
    }
    RETURN launchETA.
  }

  export(launcher).
}
