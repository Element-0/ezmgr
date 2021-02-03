import std/[uri, os]
import xmlio, vtable
import ezcommon/version_code
import ./ns

registerTypeId(VersionCode, "88fb7ac0-2538-4318-a318-80993bb63db2")
buildTypedAttributeHandler parseVersionCode

registerTypeId(Uri, "a6318113-2e5f-40c2-ac3c-19ead82e2918")
buildTypedAttributeHandler parseUri

declareXmlElement:
  type ModDescription* {.id: "8d04017d-0101-439d-989a-7b45a090203c".} = object of RootObj
    name* {.check(value == "", r"name is required").}: string
    desc* {.check(value == "", r"desc is required").}: string
    version* {.check(value == VersionCode(0), r"zero version").}: VersionCode
    author* {.check(value == "", r"author is required").}: string
    comment*: string
    license* {.check(value == "", r"license is required").}: string

func `<`*(a, b: ref ModDescription): bool = a.version < b.version
func `<=`*(a, b: ref ModDescription): bool = a.version <= b.version
func `==`*(a, b: ref ModDescription): bool = a.version == b.version

rootns.registerType("description", ref ModDescription)

trait ModInfo:
  method desc*(self: ref ModInfo): ref ModDescription
  method fetch*(self: ref ModInfo, dest: string)

proc version*(self: ref ModInfo): VersionCode = self.desc.version

registerTypeId(ref ModInfo, "0855a09b-f959-4145-864f-3e98f14aafc5")

type
  ModQuery* = object
    id*: string
    version*: Slice[VersionCode]
  ModListCallback* = proc (id: string; info: ref ModInfo): bool {.closure.}

converter toModQuery*(id: string): ModQuery =
  ModQuery(id: id, version: low(VersionCode)..high(VersionCode))

trait ModRepository:
  method query*(self: ref ModRepository; base: Uri; query: ModQuery): ref ModInfo
  method list*(self: ref ModRepository; base: Uri; callback: ModListCallback)

registerTypeId(ref ModRepository, "e3aa196d-c71b-4601-9fa1-2635949c4d88")

declareXmlElement:
  type ManagerConfig* {.id: "6a18454f-3fab-4c9f-83d2-7674bbd1855c", children: repository.} = object of RootObj
    repository* {.check(value == nil, r"repository is required").}: ref ModRepository
    cache* {.check(not dirExists(value), r"invalid folder").}: string

rootns.registerType("manager-config", ref ManagerConfig)

export ModInfo, ModRepository

{.used.}
