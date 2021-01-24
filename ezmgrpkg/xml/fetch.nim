import ezcurl, uri, streams, os

proc fetchFile*(url: Uri, dest: string) =
  let file = openFileStream(dest, fmWrite)
  try:
    defer: file.close()
    var curl = initCurlEasy()
    curl.useragent = "ezmgr/1.0"
    curl.url = $url
    curl.write = file
    curl.perform()
  except:
    removeFile(dest)
    raise getCurrentException()

proc fetchString*(url: Uri): string =
  var tmp = newStringStream ""
  block:
    var curl = initCurlEasy()
    curl.useragent = "ezmgr/1.0"
    curl.url = $url
    curl.write = tmp
    curl.perform()
  tmp.setPosition 0
  tmp.readAll()