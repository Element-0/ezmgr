import xmlio, vtable, os, tables, base, ns, fileinfo, tables, strformat, uri

declareXmlElement:
  type LocalRepository* {.id: "08c61282-c890-4f09-97ce-238b9aed2b9e".} = object of RootObj
    path {.check(not dirExists(value), r"invalid path").}: string

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

impl LocalRepository, ModRepository:
  method list*(self: ref LocalRepository, base: Uri): Table[string, ref ModInfo] =
    if base.scheme != "file":
      raise newException(ValueError, "cannot use local-repo from remote repository")
    for file in walkFiles(self.path / "ezmod-*.dll"):
      let info = parseModFile(file)
      if info.id in result:
        raise newException(ValueError, &"duplicated mod found: {info.id}")
      result[info.id] = newLocalMod(file, info.desc)

rootns.registerType("local-repo", ref LocalRepository, ref ModRepository)

{.used.}
