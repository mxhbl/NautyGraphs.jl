@testset "interface" begin
    test_graphs = [NautyGraph(0), 
                   NautyDiGraph(0), 
                   NautyGraph([1 0 1; 0 0 0; 1 0 1]),
                   NautyDiGraph([0 0 1; 1 0 0; 1 1 1])]

    @implements AbstractGraphInterface{(:mutation)} DenseNautyGraph test_graphs
    @test Interfaces.test(AbstractGraphInterface, DenseNautyGraph)
end