# This is just an example to get you started. A typical hybrid package
# uses this file as the main entry point of the application.

when not isMainModule:
  {.error: "cannot be imported".}

import std/[parseopt, strformat, streams, os, uri, strutils, tables, strtabs, options, osproc, oids]
import ezmgrpkg/xml, ezmgrpkg/properities, xmlio, ezcommon/version_code, ezpipe

proc printHelp() {.noreturn.} =
  echo "ezmgr - Cli for ElementZero"
  echo()
  echo "usage:"
  echo "ezmgr help                             Print help"
  echo "ezmgr dump                             Dump configuration"
  echo "ezmgr fetch <name>                     Download mod"
  echo "ezmgr generate <folder> ...            Generate skeleton for userdata"
  echo "ezmgr run <folder>                     Run instance at target folder"
  echo "ezmgr mod <folder> list                List mod reference for instance"
  echo "ezmgr mod <folder> add <modid>         Add mod reference to instance"
  echo "ezmgr mod <folder> del <modid>         Delete mod reference to instance"
  echo()
  echo "generate options:"
  echo "  --server-name:<servername=Element Zero>"
  echo "  --gamemode:<gamemode=creative>"
  echo "  --difficulty:<difficulty=peaceful>"
  echo "  --allow-chects[:true|false] | --disallow-cheats"
  echo "  --max-players:<num>"
  echo "  --online-mode[:true|false] | --offline-mode"
  echo "  --op-permission-level:[1|2|3|4]"
  echo "  --white-list:<filename> | --no-white-list"
  echo "  --force-gamemode[:true|false]"
  echo "  --server-port:<port=19132>"
  echo "  --server-portv6:<port=19133>"
  echo "  --wserver-retry-time:<time=0>"
  echo "  --wserver-encryption[:true|false]"
  echo "  --view-distance:<distance=8>"
  echo "  --tick-distance:<distance=4>"
  echo "  --player-idle-timeout:<timeout=30>"
  echo "  --language:<code=en_US>"
  echo "  --max-threads:<threads=8>"
  echo "  --level-name:<levelname=default>"
  echo "  --server-type:<type=normal>"
  echo "  --level-seed:<levelseed=(random)>"
  echo "  --default-player-permission-level:<level=member>"
  echo "  --server-wakeup-frequency:<freq=200>"
  echo "  --texturepack-required[:true|false] | --texturepack-optional"
  echo "  --compression-threshold:<threshold=1>"
  echo "  --msa-gamertags-only[:true|false]"
  echo "  --item-transaction-logging-enabled[:true|false]"
  echo "  --server-authoritative-movement | --client-authoritative-movement"
  echo "  --player-movement-score-threshold:<score=20>"
  echo "  --player-movement-distance-threshold:<distance=0.3>"
  echo "  --player-movement-duration-threshold-in-ms:<duration=500>"
  echo "  --correct-player-movement[:true|false]"
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

proc generateUserData(name: string, p: var OptParser) =
  if dirExists name:
    raise newException(ValueError, "cannot overwrite exists folder")
  var cfg = initCfg()
  let opt = parseCfgFromOpt(p, cfg)
  createDir(name)
  writeFile(name / "whitelist.json", "[]")
  opt.map do(whitelist_path: string):
    copyFile(whitelist_path, name / "whitelist.json")
  writeFile(name / "permissions.json", "[]")
  writeFile(name / "mods.json", "[]")
  cfg.writeCfg(name)

proc daemonThread(ipc: ref IpcPipe) {.thread.} =
  ipc.accept()
  while true:
    let cmd = ipc.recv()
    echo cmd
    ipc.send(cmd)

proc runInstance(name: string) =
  doAssert dirExists name
  var envtab = newStringTable()
  for (key, value) in envPairs():
    envtab[key] = value
  var thr: Thread[ref IpcPipe]
  let ipc = newIpcPipeServer()
  thr.createThread(daemonThread, ipc)
  envtab["EZPIPE"] = $ipc.id
  let prc = startProcess(
    command = getAppDir() / "bedrock_server.exe",
    workingDir = name,
    env = envtab,
    options = {poParentStreams})
  let code = prc.waitForExit()
  echo "exit code: ", code

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
  of "generate":
    generateUserData(p.nextArgument(), p)
  of "run":
    let name = p.nextArgument()
    p.expectKind(cmdEnd)
    runInstance(name)
  else: printHelp()
handleCLI()
