# Package

version       = "0.1.0"
author        = "CodeHz"
description   = "ElementZero Manager"
license       = "GPL-3"
srcDir        = "."
installExt    = @["nim"]
bin           = @["ezmgr"]
skipDirs      = @["tests"]


# Dependencies

requires "nim >= 1.4.2"
requires "winim"
requires "ezcommon, ezcurl, ezxmlcfg, xmlio, vtable"

from os import `/`
from strutils import strip

task prepare, "Prepare dlls":
  cpFile(gorge("nimble path ezcurl").strip / "libcurl.dll", "libcurl.dll")

before build:
  prepareTask()