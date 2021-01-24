import xmlio, vtable, uri, tables, base, ns, os, fileinfo, strformat, fetch

declareXmlElement:
  type ModManifest* {.id: "e18cdb2d-efda-4d01-bf36-cbdf21eb6db9", children: description.} = object of RootObj
    href: Uri
    description: ref ModDescription
    id {.skipped.}: string

impl ModManifest, ModInfo:
  method desc*(self: ref ModManifest): ref ModDescription = self.description
  method fetch*(self: ref ModManifest, dest: string) =
    fetchFile(self.href, dest)
    let ret = parseModFile(dest)
    if ret.id != self.id:
      removeFile(dest)
      raise newException(ValueError, &"mod id not matched, expected {self.id}, but got {ret.id}")

rootns.registerType("manifest", ref ModManifest)

declareXmlElement:
  type ManifestRepository* {.id: "f0067348-0817-405c-9e1d-44e00492fb34".} = object of RootObj
    children: Table[string, ref ModManifest]

impl ManifestRepository, ModRepository:
  method list*(self: ref ManifestRepository): Table[string, ref ModInfo] =
    for id, val in self.children:
      val.id = id
      result[id] = val

rootns.registerType("manifest-repo", ref ManifestRepository, ref ModRepository)

{.used.}
