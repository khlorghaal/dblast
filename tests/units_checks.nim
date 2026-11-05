## Test map: saturation bounds.
import std/[math, unittest]
import ../src/blastd

suite "blastd scalar utilities":
  test "saturation clamps both bounds and preserves interior values":
    check sat(-0.5'f32) == 0'f32
    check sat(0'f32) == 0'f32
    check sat(0.375'f32) == 0.375'f32
    check sat(1'f32) == 1'f32
    check sat(1.5'f32) == 1'f32
    check sat(Inf.float32) == 1'f32
    check sat(NegInf.float32) == 0'f32
