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
requires "ezcommon, ezcurl, ezxmlcfg, xmlio, vtable"
