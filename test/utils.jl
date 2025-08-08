
@testset "utils" begin
   # Test that sha works without error
   A = ones(10_000)
   NautyGraphs.hash_sha(ones(10_000))
   @test true
end
