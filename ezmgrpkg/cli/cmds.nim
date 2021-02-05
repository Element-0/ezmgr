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

type
  FetchVersionStrategy = enum
    fvs_latest
    fvs_exact
    fvs_range
  FetchInfo = object
    name: string
    case strategy: FetchVersionStrategy
    of fvs_latest: discard
    of fvs_exact: version: VersionCode
    of fvs_range: min, max: VersionCode

converter toModQuery(info: FetchInfo): ModQuery =
  result.id = info.name
  result.version = case info.strategy:
    of fvs_latest: low(VersionCode)..high(VersionCode)
    of fvs_exact: info.version .. info.version
    of fvs_range: info.min .. info.max

func parseFetchInfo(p: var OptParser): FetchInfo =
  var
    name: string
    strategy: FetchVersionStrategy
    ver, min, max: Option[VersionCode]
  while true:
    p.next()
    case p.kind:
    of cmdArgument:
      if name == "":
        name = p.key
      elif strategy == fvs_latest:
        strategy = fvs_exact
        ver = some parseVersionCode p.key
      else:
        raise newException(ValueError, "Can only fetch one mod at a time")
    of cmdLongOption:
      let px = case p.key:
      of "min": addr min
      of "max": addr max
      else:
        raise newException(ValueError, "Invalid option: --" & p.key)
      if strategy == fvs_exact:
        raise newException(ValueError, "Invalid version range")
      strategy = fvs_range
      px[] = some parseVersionCode p.val
    of cmdShortOption:
      raise newException(ValueError, "Invalid option: -" & p.key)
    of cmdEnd: break
  if name == "":
    raise newException(ValueError, "No mod id specified")
  case strategy:
  of fvs_latest: FetchInfo(name: name, strategy: fvs_latest)
  of fvs_exact: FetchInfo(name: name, strategy: fvs_exact, version: ver.unsafeGet())
  of fvs_range: FetchInfo(name: name, strategy: fvs_range, min: min.get(low(VersionCode)), max: max.get(high(VersionCode)))

proc fetchMod*(p: var OptParser) =
  let info = parseFetchInfo(p)
  let cfg = loadCfg()
  let modinfo = cfg.content.repository.query(cfg.base, info)
  if modinfo == nil:
    raise newException(KeyError, &"mod {info.name} not found")
  let filename = getModCachedName(info.name, modinfo)
  modinfo.fetch(cfg.content.cache / filename)
  echo "Downloaded to ", filename

proc generateUserData*(name: string; p: var OptParser) =
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
