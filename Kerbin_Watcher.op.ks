{
  for dependency in list(
    "mission_runner.v0.1.0.ks",
    "launcher.v0.1.0.ks",
    "Missions/kerbinwatcher_mission.ks",
    "event_lib.v0.1.0.ks"
  ) if not exists(dependency) copypath("0:"+dependency, path()).

  run mission_runner.v0.1.0.ks.
  run event_lib.v0.1.0.ks.
  run launcher.v0.1.0.ks.
  run kerbinwatcher_mission.ks.

  run_mission(kerbinwatcher_mission["sequence"], kerbinwatcher_mission["events"]).
}
