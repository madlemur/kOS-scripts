@LAZYGLOBAL OFF.
print("os.ks vBUILD_VERSION.BUILD_RELEASE.BUILD_PATCH BUILD_DATE").
{
  LOCAL lib_os IS LEXICON(
    "import", import@,
    "export", export@,
    "loadScript", loadScript@,
    "delScript", delScript@,
    "append", append@,
    "store", store@,
    "resume", resume@
  ).

  local s is stack().
  local d is lex().

  LOCAL VOLUME_NAMES IS listVolumes().
  pVolumes(VOLUME_NAMES).

  LOCAL FUNCTION import {
    PARAMETER n.
    if not d:HASKEY(n) {
        s:PUSH(n).
        RUNONCEPATH(loadScript("1:/"+n)).
    }
    RETURN d[n].
  }

  LOCAL FUNCTION export {
    PARAMETER v.
    SET d[s:POP()] TO v.
  }

  LOCAL FUNCTION setVolumeList
  {
    PARAMETER vnl.
    SET VOLUME_NAMES TO vnl.
    pVolumes().
  }

  LOCAL FUNCTION listVolumes
  {
    IF CORE:CURRENTVOLUME:NAME = "" { SET CORE:CURRENTVOLUME:NAME TO "Disk0". }
    LOCAL cvn IS CORE:CURRENTVOLUME:NAME.
    LOCAL VOLUME_NAMES IS LIST(cvn).

    LOCAL disk_num IS 1.
    LOCAL pl IS LIST().
    LIST PROCESSORS IN pl.
    FOR p IN pl {
      LOCAL LOCK vn TO p:VOLUME:NAME.
      IF p:MODE = "READY" AND p:BOOTFILENAME = "None" AND vn <> cvn {
        IF vn = "" {
          SET p:VOLUME:NAME TO ("Disk" + disk_num).
          SET disk_num TO disk_num + 1.
        }
        VOLUME_NAMES:ADD(vn).
      }
    }
    return VOLUME_NAMES.
  }

  LOCAL FUNCTION pVolumes
  {
    PARAMETER VOLUME_NAMES IS LIST().
    FOR vn IN VOLUME_NAMES { PRINT("Volume(" + vn + ") has " + VOLUME(vn):FREESPACE + " bytes."). }
  }

  LOCAL FUNCTION findPath
  {
    PARAMETER fn.
    FOR vn IN VOLUME_NAMES {
      LOCAL lfp IS vn + ":/" + fn.
      IF EXISTS(lfp) { RETURN lfp. }
    }
    RETURN "".
  }

  LOCAL FUNCTION findSpace
  {
    PARAMETER fn, mfs.
    FOR vn IN VOLUME_NAMES { IF VOLUME(vn):FREESPACE > mfs { RETURN vn + ":/" + fn. } }
    PRINT("ERROR: no room!").
    pVolumes().
    RETURN "".
  }

  LOCAL FUNCTION loadScript
  {
    PARAMETER fn, dfn IS "", loud IS TRUE.
    IF dfn = "" {
      SET dfn to fn.
    }
    LOCAL lfp IS findPath(dfn).
    PRINT("Checking " + dfn).
    IF lfp <> "" { RETURN lfp. }

    LOCAL afp IS "0:/" + fn.
    PRINT("Checking " + afp).
    if EXISTS(afp) {
      LOCAL afs IS VOLUME(0):OPEN(fn):SIZE.
      IF loud { PRINT("Copying from: " + afp + " (" + afs + " bytes)"). }

      SET lfp TO findSpace(dfn, afs).
      COPYPATH(afp,lfp).
      IF loud { PRINT("Copied to: " + lfp). }
      RETURN lfp.
    } ELSE {
      RETURN "".
    }
  }

  LOCAL FUNCTION delScript
  {
    PARAMETER fn.
    LOCAL lfp IS findPath(fn).
    IF lfp <> "" { DELETEPATH(lfp). }
  }

  LOCAL FUNCTION delResume
  {
    delScript(RESUME_FN).
  }

  LOCAL FUNCTION store
  {
    PARAMETER t, fn IS RESUME_FN, mfs IS 150.
    delScript(fn).
    LOG t TO findSpace(fn,mfs).
  }

  LOCAL FUNCTION append
  {
    PARAMETER t, fn IS RESUME_FN.
    LOG t TO findPath(fn).
  }

  LOCAL FUNCTION resume
  {
    PARAMETER fn IS RESUME_FN.
    LOCAL lfp IS findPath(fn).
    IF lfp <> "" { RUNPATH(lfp). }
  }
  // Faking an export here, since there was no import. Chicken. Egg. :/
  SET d["lib/os.ks"] TO lib_os.
  global _os_ is lib_os.
}
