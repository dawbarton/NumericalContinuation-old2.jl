@testset "Signals & slots" begin
    _f1 = Ref(0)
    f1 = (x; y=1) -> (_f1[] += 1; x+y)
    _f2 = Ref(0)
    f2 = (x; y) -> (_f2[] += 1; x*y)
    signals = NC.Signals()
    NC.add_signal!(signals, :test1, :((x; y)))
    NC.add_signal!(signals, :test2, :((x; y=1)))
    @test_throws ArgumentError NC.add_signal!(signals, :test1, :((x; y)))
    NC.connect_signal!(signals, :test1, f1)
    @test_throws ArgumentError NC.connect_signal!(signals, :test1, f1)
    @test_throws ArgumentError NC.connect_signal!(signals, :random, f1)
    NC.connect_signal!(signals, :test1, f2)
    NC.connect_signal!(signals, :test2, f1)
    NC.emit_signal(signals, :test1, 1.5, y=1.5)
    @test _f1[] == 1
    @test _f2[] == 1
    NC.emit_signal(signals, :test2, 1.5)
    @test _f1[] == 2
    NC.emit_signal(signals, :test2, 1.5, y=1.0)
    @test _f1[] == 3
end
