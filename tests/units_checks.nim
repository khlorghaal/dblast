import std/[math, unittest]
import ../src/[blastd, units]

suite "blastd scalar utilities":
  test "saturation clamps both bounds and preserves interior values":
    check sat(-0.5'f32) == 0'f32
    check sat(0'f32) == 0'f32
    check sat(0.375'f32) == 0.375'f32
    check sat(1'f32) == 1'f32
    check sat(1.5'f32) == 1'f32
    check sat(Inf.float32) == 1'f32
    check sat(NegInf.float32) == 0'f32

  test "milliseconds convert to seconds":
    check float64(seconds(Milliseconds(0))) == 0
    check float64(seconds(Milliseconds(1250))) == 1.25
    check float64(seconds(Milliseconds(-500))) == -0.5

  test "seconds convert to rounded milliseconds":
    check milliseconds(Seconds(0)) == Milliseconds(0)
    check milliseconds(Seconds(1.234)) == Milliseconds(1234)
    check milliseconds(Seconds(-0.5)) == Milliseconds(-500)
    check milliseconds(Seconds(0.0004)) == Milliseconds(0)
    check milliseconds(Seconds(0.0006)) == Milliseconds(1)

  test "time values compare and seconds add and subtract":
    check Milliseconds(100) < Milliseconds(101)
    check Milliseconds(100) == Milliseconds(100)
    check Seconds(1) < Seconds(2)
    check Seconds(2) <= Seconds(2)
    check float64(Seconds(1) + Seconds(2)) == 3
    check float64(Seconds(3) - Seconds(1)) == 2
    var elapsed = Seconds(1)
    elapsed += Seconds(0.25)
    check float64(elapsed) == 1.25

  test "milliseconds rejects non-finite values":
    expect ValueError:
      discard milliseconds(Seconds(Inf))
    expect ValueError:
      discard milliseconds(Seconds(NegInf))
    expect ValueError:
      discard milliseconds(Seconds(NaN))

  test "milliseconds rejects values outside int64 range":
    expect ValueError:
      discard milliseconds(Seconds(float64(high(int64))))
    expect ValueError:
      discard milliseconds(Seconds(float64(low(int64))))
