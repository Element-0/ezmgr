import std/[strformat, os, parseopt, options]
import ezcommon/version_code
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
  cfg.content.repository.list(cfg.base) do(id: string; info: ref ModInfo) -> bool:
    echo id, ":", info.desc()[]

proc fetchMod*(name: string) =
  let cfg = loadCfg()
  let modinfo = cfg.content.repository.query(cfg.base, name)
  if modinfo == nil:
    raise newException(KeyError, &"mod {name} not found")
  modinfo.fetch(cfg.content.cache / &"cached-{name}-{modinfo.version}.dll")

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