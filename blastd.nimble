version     = "0.1.0"
author      = "khlorghaal"
description = "blastd — peer-to-peer data distribution"
license     = "GPL-3.0"
srcDir      = "src"

requires "nim >= 2.0.0"

task test, "Run the peer-to-peer core checks":
  exec "mkdir -p build"
  exec "nim c -r -o:build/core-checks tests/core_checks.nim"
