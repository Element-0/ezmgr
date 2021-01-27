import std/[tables, strformat, os, parseopt, options]
import ../xml, ../properties
import ./shared

proc printHelp*() {.noreturn.} =
  const help = slurp"help.txt"
  echo help
  quit 0

proc dumpConfig*() =
  let cfg = loadCfg()
  echo "cache path: ", cfg.content.cache
  echo "mod list:"
  for id, ifo in cfg.content.repository.list(cfg.base):
    echo id, ":", ifo.desc()[]

proc fetchMod*(name: string) =
  let cfg = loadCfg()
  var modmap = cfg.content.repository.list(cfg.base)
  modmap.withValue(name, value) do:
    value[].fetch(cfg.content.cache / &"cached-{name}.dll")
  do:
    raise newException(KeyError, &"mod {name} not found")

proc generateUserData*(name: string, p: var OptParser) =
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