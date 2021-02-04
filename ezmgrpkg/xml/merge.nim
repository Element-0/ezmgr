import std/uri, xmlio, vtable
import ezcommon/version_code
import ./base, ./ns

declareXmlElement:
  type MergeRepository* {.id: "df4cd0df-ce37-457f-a3f8-ac5d38742b21", children: repos.} = object of RootObj
    repos {.check(value.len == 0, r"no repo found").}: seq[ref ModRepository]

impl MergeRepository, ModRepository:
  method query*(self: ref MergeRepository; base: Uri; query: ModQuery): ref ModInfo =
    for repo in self.repos:
      let tmp = repo.query(base, query)
      if tmp != nil:
        if result != nil:
          if tmp.desc().version > result.desc().version:
            result = tmp
        else:
          result = tmp

  method list*(self: ref MergeRepository; base: Uri; callback: ModListCallback) =
    for repo in self.repos:
      repo.list(base, callback)

rootns.registerType("merge-repo", ref MergeRepository, ref ModRepository)

{.used.}
