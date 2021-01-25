import xmlio, vtable, tables, base, ns, uri
import ezcommon/version_code

declareXmlElement:
  type MergeRepository* {.id: "df4cd0df-ce37-457f-a3f8-ac5d38742b21", children: repos.} = object of RootObj
    repos {.check(value.len == 0, r"no repo found").}: seq[ref ModRepository]

impl MergeRepository, ModRepository:
  method list*(self: ref MergeRepository, base: Uri): Table[string, ref ModInfo] =
    for repo in self.repos:
      for key, value in repo.list(base):
        result.withValue(key, tmp):
          if tmp[].desc().version < value.desc().version:
            tmp[] = value
        do:
          result[key] = value

rootns.registerType("merge-repo", ref MergeRepository, ref ModRepository)

{.used.}
