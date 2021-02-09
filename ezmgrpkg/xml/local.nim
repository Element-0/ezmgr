import std/[os, uri], xmlio, vtable, ezcommon/version_code
import ./base, ./ns, ./fileinfo

type LocalMod = object of RootObj
  path: string
  description: ref ModDescription

proc newLocalMod(path: string, description: ref ModDescription): ref LocalMod =
  new result
  result[].path = path
  result[].description = description

impl LocalMod, ModInfo:
  method desc*(self: ref LocalMod): ref ModDescription = self.description
  method fetch*(self: ref LocalMod, dest: string) = copyFile(self.path, dest)

declareXmlElement:
  type LocalRepository* {.id: "08c61282-c890-4f09-97ce-238b9aed2b9e".} = object of RootObj
    path {.check(not dirExists(value), r"invalid path").}: string
    cache {.skipped.}: seq[tuple[id: string, info: ref LocalMod]]
do:
  for file in walkFiles(self.path / "ezmod-*.dll"):
    let info = parseModFile(file)
    info.desc.kind = modServerSide
    self.cache.add (id: info.id, info: newLocalMod(file, info.desc))
  for file in walkFiles(self.path / "ezmgr-*.dll"):
    let info = parseModFile(file)
    info.desc.kind = modManagerSide
    self.cache.add (id: info.id, info: newLocalMod(file, info.desc))

impl LocalRepository, ModRepository:
  method query*(self: ref LocalRepository; base: Uri; query: ModQuery): ref ModInfo =
    if base.scheme != "file":
      raise newException(ValueError, "cannot use local-repo from remote repository")
    for item in self.cache:
      if item.id == query.id:
        if item.info.description.version in query.version:
          if result != nil:
            if item.info.description.version < result.desc().version:
              continue
          result = item.info
    discard
  method list*(self: ref LocalRepository; base: Uri; callback: ModListCallback) =
    if base.scheme != "file":
      raise newException(ValueError, "cannot use local-repo from remote repository")
    for item in self.cache:
      if callback(item.id, item.info):
        return

rootns.registerType("local-repo", ref LocalRepository, ref ModRepository)

{.used.}
