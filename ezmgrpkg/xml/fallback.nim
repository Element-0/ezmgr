import std/uri, xmlio, vtable
import ./base, ./ns

declareXmlElement:
  type FallbackRepository* {.id: "df4cd0df-ce37-457f-a3f8-ac5d38742b21", children: repos.} = object of RootObj
    repos {.check(value.len == 0, r"no repo found").}: seq[ref ModRepository]

impl FallbackRepository, ModRepository:
  method query*(self: ref FallbackRepository; base: Uri; query: ModQuery): ref ModInfo =
    for repo in self.repos:
      try:
        result = repo.query(base, query)
        if result != nil:
          return
      except:
        discard

  method list*(self: ref FallbackRepository; base: Uri; callback: ModListCallback) =
    for repo in self.repos:
      try:
        repo.list(base, callback)
        return
      except:
        discard
    raise newException(ValueError, "all fallback failed")

rootns.registerType("fallback-repo", ref FallbackRepository, ref ModRepository)

{.used.}
