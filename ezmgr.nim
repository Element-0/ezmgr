# This is just an example to get you started. A typical hybrid package
# uses this file as the main entry point of the application.

when not isMainModule:
  {.error: "cannot be imported".}

import parseopt, strformat, streams, os, uri, strutils, tables
import ezmgrpkg/xml, xmlio, ezcommon/version_code

proc printHelp() {.noreturn.} =
  echo "ezmgr - Cli for ElementZero"
  echo()
  echo "usage:"
  echo "ezmgr help           Print help"
  echo "ezmgr dump           Dump configuration"
  quit 0

# FIXME: don't use noreturn
proc dumpConfig() {.noreturn.} =
  let path = getAppDir() / "ezmgr.xml"
  let str = openFileStream(path)
  let cfg = readXml(root, str, path, ref ManagerConfig)
  var cururl = initUri()
  cururl.scheme = "file"
  cururl.path = path.replace('\\', '/')
  for id, ifo in cfg.repository.list(cururl):
    echo id, ":", ifo.desc()[]
  quit 0

proc handleCLI() =
  var p = initOptParser()
  while true:
    p.next()
    case p.kind:
    of cmdEnd, cmdShortOption, cmdLongOption: printHelp()
    of cmdArgument:
      case p.key:
      of "help": printHelp()
      of "dump": dumpConfig()
      else: quit &"invalid subcommand: {p.key}"

handleCLI()