import os

const fensterHeader = currentSourcePath().parentDir() / "fenster/fenster.h"

when defined(linux): {.passl: "-lX11".}
elif defined(windows): {.passl: "-lgdi32".}
elif defined(macosx): {.passl: "-framework Cocoa".}

{.passC: "-Ivendor".}

type
  FensterStruct = object
    title*: cstring
    width*: cint
    height*: cint
    buf*: ptr UncheckedArray[uint32]
    keys*: array[256, cint]
    modkey*: cint
    x*: cint
    y*: cint
    mouse*: cint
  
  Fenster* = object
    raw: ptr FensterStruct
    targetFps: int
    lastFrameTime: int64

{.push importc, header: fensterHeader.}
proc fenster_open(fenster: ptr FensterStruct): cint
proc fenster_loop(fenster: ptr FensterStruct): cint
proc fenster_close(fenster: ptr FensterStruct)
proc fenster_sleep(ms: cint)
proc fenster_time(): int64
{.pop.}

proc `=destroy`(self: Fenster) =
  fenster_close(self.raw)
  dealloc(self.raw.buf)
  dealloc(self.raw)

proc init*(_: type Fenster, title: string, width: int, height: int, fps: int = 60): Fenster =
  result = Fenster()
  
  result.raw = cast[ptr FensterStruct](alloc0(sizeof(FensterStruct)))
  result.raw.title = cstring(title)
  result.raw.width = cint(width)
  result.raw.height = cint(height)
  result.raw.buf =
    cast[ptr UncheckedArray[uint32]](alloc(width * height * sizeof(uint32)))
  
  result.targetFps = fps
  result.lastFrameTime = fenster_time()
  
  discard fenster_open(result.raw)

proc loop*(self: var Fenster): bool =
  let frameTime = 1000 div self.targetFps
  let currentTime = fenster_time()
  let elapsedTime = currentTime - self.lastFrameTime
  
  if elapsedTime < frameTime:
    fenster_sleep((frameTime - elapsedTime).cint)
  
  self.lastFrameTime = fenster_time()
  result = fenster_loop(self.raw) == 0

proc sleep*(ms: int) = fenster_sleep(ms.cint)
proc time*(): int64 = fenster_time()

proc `[]`*(self: Fenster, x, y: int): uint32 =
  self.raw.buf[y * self.raw.width + x]

proc `[]=`*(self: Fenster, x, y: int, color: SomeInteger) =
  self.raw.buf[y * self.raw.width + x] = color.uint32

proc `[]=`*(self: Fenster, x, y: int, color: tuple[r, g, b: uint8]) =
  let packed = (uint32(color.r) shl 16) or (uint32(color.g) shl 8) or uint32(color.b)
  self.raw.buf[y * self.raw.width + x] = packed

proc width*(self: Fenster): int = self.raw.width.int
proc height*(self: Fenster): int = self.raw.height.int
proc keys*(self: Fenster): array[256, cint] = self.raw.keys
proc mouse*(self: Fenster): tuple[x, y, click: int] = (self.raw.x.int, self.raw.y.int, self.raw.mouse.int)
proc modkey*(self: Fenster): int = self.raw.modkey.int

proc targetFps*(self: Fenster): int = self.targetFps
proc `targetFps=`*(self: var Fenster, fps: int) = self.targetFps = fps