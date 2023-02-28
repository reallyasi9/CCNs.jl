using CCNs
using Test

@testset "CCNs.jl" begin
    @testset "MedicareProviderCCN" begin
        @testset "constructor" begin
            @test MedicareProviderCCN("123456").number == "123456"
            @test MedicareProviderCCN("QWERTYU").number == "QWERTYU"
            # Doesn't fit within String7 size
            @test_throws ArgumentError MedicareProviderCCN("12345678")
        end
        @testset "ccn function" begin
            @test ccn(MedicareProviderCCN, "123456") == MedicareProviderCCN("123456")
            @test ccn(MedicareProviderCCN, "QWERTY") == MedicareProviderCCN("QWERTY")
            @test ccn(MedicareProviderCCN, "") == MedicareProviderCCN("000000")
            @test ccn(MedicareProviderCCN, "1") == MedicareProviderCCN("000001")
            # Too many characters
            @test_throws ArgumentError ccn(MedicareProviderCCN, "QWERTYU")

            @test ccn(MedicareProviderCCN, 123456) == MedicareProviderCCN("123456")
            @test ccn(MedicareProviderCCN, 1) == MedicareProviderCCN("000001")
            # Too many characters
            @test_throws ArgumentError ccn(MedicareProviderCCN, 1234567)
            # Negative value
            @test_throws ArgumentError ccn(MedicareProviderCCN, -1)
            
            # other numbers
            @test ccn(MedicareProviderCCN, 1.0) == MedicareProviderCCN("000001")
            @test ccn(MedicareProviderCCN, Rational(5, 5)) == MedicareProviderCCN("000001")
            # Inexact
            @test_throws InexactError ccn(MedicareProviderCCN, 1.00000001)
        end
        @testset "string and repr" begin
            @test string(MedicareProviderCCN("123456")) == "123456"
            @test repr(MIME("text/plain"), MedicareProviderCCN("123456")) == "MedicareProviderCCN(\"123456\")"
        end
        @testset "isvalid" begin
            @test isvalid(MedicareProviderCCN("123456"))
            @test isvalid(MedicareProviderCCN("12P456"))
            # Too many characters
            @test !isvalid(MedicareProviderCCN("1234567"))
            # Not enough characters
            @test !isvalid(MedicareProviderCCN("12345"))
            # Invalid state code
            @test !isvalid(MedicareProviderCCN("XX3456"))
            # Invalid type code (lower case)
            @test !isvalid(MedicareProviderCCN("12p456"))
            # Invalid type code (non-digit, not 'P')
            @test !isvalid(MedicareProviderCCN("12A456"))
            # Invalid sequence number (non-digit)
            @test !isvalid(MedicareProviderCCN("12345E"))
        end
    end
end