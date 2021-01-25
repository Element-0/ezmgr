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
  echo "ezmgr fetch [name]   Fetch mod"
  quit 0

proc loadCfg(): tuple[content: ref ManagerConfig, base: Uri] =
  let path = getAppDir() / "ezmgr.xml"
  let str = openFileStream(path)
  result.content = readXml(root, str, path, ref ManagerConfig)
  var cururl = initUri()
  cururl.scheme = "file"
  cururl.path = path.replace('\\', '/')
  result.base = cururl

proc dumpConfig() =
  let cfg = loadCfg()
  echo "cache path: ", cfg.content.cache
  echo "mod list:"
  for id, ifo in cfg.content.repository.list(cfg.base):
    echo id, ":", ifo.desc()[]

proc fetch(name: string) =
  let cfg = loadCfg()
  var modmap = cfg.content.repository.list(cfg.base)
  modmap.withValue(name, value) do:
    value[].fetch(cfg.content.cache / &"cached-{name}.dll")
  do:
    raise newException(KeyError, &"mod {name} not found")

proc nextArgument(p: var OptParser): string =
  p.next()
  if p.kind == cmdArgument:
    return p.key
  echo &"except argument, got {p.kind}"
  printHelp()

proc expectKind(p: var OptParser, kind: static CmdLineKind) =
  p.next()
  if p.kind != kind:
    echo &"expect {kind}, got {p.kind}"
    printHelp()

proc handleCLI() =
  var p = initOptParser()
  case p.nextArgument():
  of "help": printHelp()
  of "dump":
    p.expectKind(cmdEnd)
    dumpConfig()
  of "fetch":
    let name = p.nextArgument()
    p.expectKind(cmdEnd)
    fetch(name)
  else: printHelp()
handleCLI()