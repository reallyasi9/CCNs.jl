module CCNs

using InlineStrings
import Base: show, print, isvalid

export MedicareProviderCCN, MedicaidOnlyProviderCCN, IPPSExcludedProviderCCN, EmergencyHospitalCCN, SupplierCCN
export ccn, infer_ccn_type, clean_ccn, decode

include("statecodes.jl")
include("facilitytypecodes.jl")
include("suppliercodes.jl")

"""
    CCN

A representation of a CMS Certification Number.

CCNs are a uniform way of identifying providers or suppliers who currently or who ever have participated in the Medicare or Medicaid programs.
A CCN is a 6- or 10-character alphanumeric string that encodes the provider or supplier's (respectively) State and facility type.

CCNs can be constructed from `AbstractString` or `Integer` objects, but `Integer`s can only represent a subset of all possible CCNs.

CCNs are defined by CMS Manual System publication number 100-07 "State Operations Provider Certification".
"""
abstract type CCN end

abstract type ProviderCCN <: CCN end

struct MedicareProviderCCN <: ProviderCCN
    number::String7
end

struct MedicaidOnlyProviderCCN <: ProviderCCN
    number::String7
end

struct IPPSExcludedProviderCCN <: ProviderCCN
    number::String7
end

struct EmergencyHospitalCCN <: ProviderCCN
    number::String7
end

struct SupplierCCN <: CCN
    number::String15
end

"""
    ccn([T::Type], s)

Construct a CCN from input `s`.

# Arguments
    - `T::Type` (optional) - The type of the CCN. If no type is given, the best guess of the type will be made based on the format of the input `s`.
    - `s::Union{AbstractString,Integer}` - The input to parse to create the CCN.

# Return value
Returns a CCN of concrete type `T` if given, else the type will be inferred from format of `s`.
"""
function ccn(::Type{SupplierCCN}, s::AbstractString)
    pad = 10
    length(s) > pad && throw(ArgumentError("SupplierCCN cannot be more than $pad characters in length"))
    return SupplierCCN(String15(lpad(uppercase(s), pad, '0')))
end

function ccn(::Type{T}, s::AbstractString) where {T <: ProviderCCN}
    pad = 6
    length(s) > pad && throw(ArgumentError("$T cannot be more than $pad characters in length"))
    return T(String7(lpad(uppercase(s), pad, '0')))
end

function ccn(::Type{T}, i::Integer) where {T <: ProviderCCN}
    i < 0 && throw(ArgumentError("$T cannot be a negative number"))
    pad = 6
    ndigits(i) > pad && throw(ArgumentError("$T cannot be more than $pad digits in base 10"))
    return T(String7(lpad(string(i), 6, '0')))
end

function ccn(s::AbstractString)
    c = clean_ccn(s)
    T = infer_ccn_type(c)
    return ccn(T, c)
end

function clean_ccn(s::AbstractString)
    ss = strip(s)
    if ss[3] == "-" # dash sometimes appears between state code and remainder
        ss = ss[1:2] * ss[4:end]
    end
    length(ss) > 10 && throw(ArgumentError("CCNs cannot be more than 10 characters in length"))
    pad = length(ss) > 6 ? 10 : 6
    return lpad(ss, pad, '0')
end

function clean_ccn(i::Integer)
    i < 0 && throw(ArgumentError("CCNs cannot be negative"))
    ndigits(i) > 6 && throw(ArgumentError("Integer CCNs cannot be more than 6 digits in base 10"))
    return lpad(string(i; base=10), 6, '0')
end

"""
    infer_ccn_type(s) -> `Type{T} where T <: CCN`

Infer the type of the CCN from the input.

# Arguments
    - `s::Union{AbstractString,Integer}` - The value to parse.

# Return value
The inferred type. Throws if the type cannot be inferred from the input.
"""
function infer_ccn_type(s::AbstractString)
    length(s) ∉ (6, 10) && throw(ArgumentError("CCN must be a 6- or 10-character string"))
    length(s) == 10 && return SupplierCCN
    tc = s[3]
    tc ∈ MEDICAID_TYPE_CODES && return MedicaidOnlyProviderCCN
    tc ∈ IPPS_EXCLUDED_TYPE_CODES && return IPPSExcludedProviderCCN
    s[6] ∈ keys(EMERGENCY_CODES) && return EmergencyHospitalCCN
    (tc == 'P' || isdigit(tc)) && return MedicareProviderCCN
    throw(ArgumentError("CCN type cannot be inferred from '$s'"))
end

function ccn(i::Integer)
    # can only be a MedicareProviderCCN
    return ccn(MedicareProviderCCN, i)
end

Base.convert(::Type{T}, s::AbstractString) where {T <: CCN} = ccn(T, s)
Base.convert(::Type{T}, i::Integer) where {T <: CCN} = ccn(T, i)

Base.parse(::Type{T}, s::AbstractString) where {T <: CCN} = ccn(T, s)
function Base.tryparse(::Type{T}, s::AbstractString) where {T <: CCN}
    try
        return parse(T, s)
    catch
        return nothing
    end
end

Base.show(io::IO, n::T) where {T <: CCN} = show(io, "$T(\"$(n.number)\")")
Base.print(io::IO, n::T) where (T <: CCN) = print(io, n.number)

function Base.isvalid(c::MedicareProviderCCN)
    n = c.number
    length(n) == 6 || return false
    n[1:2] ∈ keys(STATE_CODES) || return false
    mapreduce(isdigit, &, n[4:6]) || return false
    return n[3] == 'P' || isdigit(n[3])
end

function Base.isvalid(c::MedicaidOnlyProviderCCN)
    n = c.number
    length(n) == 6 || return false
    n[1:2] ∈ keys(STATE_CODES) || return false
    n[3] ∈ MEDICAID_TYPE_CODES || return false
    return mapreduce(isdigit, &, n[4:6])
end

function Base.isvalid(c::IPPSExcludedProviderCCN)
    n = c.number
    length(n) == 6 || return false
    n[1:2] ∈ keys(STATE_CODES) || return false
    n[3] ∈ IPPS_EXCLUDED_TYPE_CODES || return false
    isdigit(n[4]) || n[4] ∈ ('A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'J', 'K')|| return false
    return mapreduce(isdigit, &, n[5:6])
end

function Base.isvalid(c::EmergencyHospitalCCN)
    n = c.number
    length(n) == 6 || return false
    n[1:2] ∈ keys(STATE_CODES) || return false
    n[6] ∈ keys(EMERGENCY_CODES) || return false
    return mapreduce(isdigit, &, n[3:5])
end

function Base.isvalid(c::SupplierCCN)
    n = c.number
    length(n) == 10 || return false
    n[1:2] ∈ keys(STATE_CODES) || return false
    n[3] ∈ keys(SUPPLIER_CODES) || return false
    return mapreduce(isdigit, &, n[4:10])
end

"""
    decode([io::IO = stdout], ccn)

Decode `ccn` and write the information to `io`.
"""
function decode(io::IO, ccn::MedicareProviderCCN)
    print(io, ccn.number, ": Medicare Provider")
    state_number = ccn.number[1:2]
    state = get(STATE_CODES, state_number, "invalid state")
    print(io, " in $state ($state_number)")
    if ccn.number[3] == 'P'
        type_code = "P"
        type = "Organ Procurement Organization (OPO)"
        sequence = parse(Int64, ccn.number[4:6])
    else
        sequence = parse(Int64, ccn.number[3:6])
        idx = findfirst(x -> sequence ∈ first(x), FACILITY_RANGES)
        if isnothing(idx)
            type = "invalid facility type"
            type_code = ccn.number[3:6]
        else
            val = FACILITY_RANGES[idx]
            range = first(val)
            type_code = lpad(first(range), 4, '0') * "-" * lpad(last(range), 4, '0')
            type = last(val)
            sequence -= first(range)
        end
    end
    print(io, ", $type ($type_code) sequence number $sequence")
end

function decode(io::IO, ccn::MedicaidOnlyProviderCCN)
    print(io, ccn.number, ": Medicaid-only Provider")
    state_number = ccn.number[1:2]
    state = get(STATE_CODES, state_number, "invalid state")
    print(io, " in $state ($state_number)")

    type_code = ccn.number[3]
    sequence = parse(Int64, ccn.number[4:6])
    
    if type_code == 'J'
        idx = findfirst(x -> sequence ∈ first(x), MEDICAID_HOSPITAL_RANGES)
        if isnothing(idx)
            type = "Medicaid-Only Hospital (invalid type)"
        else
            val = MEDICAID_HOSPITAL_RANGES[idx]
            range = first(val)
            type_code = "J" * lpad(first(range), 3, '0') * "-J" * lpad(last(range), 3, '0')
            type = last(val)
            sequence -= first(range)
        end
    else
        type = get(MEDICAID_FACILITY_CODES, type_code, "invalid facility type")
    end
    print(io, ", $type ($type_code) sequence number $sequence")
end

function decode(io::IO, ccn::IPPSExcludedProviderCCN)
    print(io, ccn.number, ": IPPS-Excluded Provider")
    state_number = ccn.number[1:2]
    state = get(STATE_CODES, state_number, "invalid state")
    print(io, " in $state ($state_number)")

    type_code = ccn.number[3]
    sequence_code = ccn.number[4:6]

    type = get(MEDICAID_FACILITY_CODES, type_code, "invalid facility type")

    if !isdigit(sequence_code[1])
        parent_code = sequence_code[1]
        parent_type = get(IPPS_PARENT_HOSPITAL_TYPES, parent_code, ("invalid parent type" => ""))
        sequence_code = last(parent_type) * sequence_code[2:end]
        print(io, ", $type ($type_code) of parent $(first(parent_type)) ($parent_code) with sequence number ending in $sequence_code")
    else
        print(io, ", $type ($type_code) of parent with sequence number ending in $sequence_code")
    end
end

function decode(io::IO, ccn::EmergencyHospitalCCN)
    print(io, ccn.number, ": Emergency Hospital")
    state_number = ccn.number[1:2]
    state = get(STATE_CODES, state_number, "invalid state")
    print(io, " in $state ($state_number)")

    type_code = ccn.number[6]
    type = get(EMERGENCY_CODES, type_code, "invalid emergency hospital type")

    sequence = parse(Int64, ccn.number[3:5])
    
    print(io, ", $type ($type_code) sequence number $sequence")
end

function decode(io::IO, ccn::SupplierCCN)
    print(io, ccn.number, ": Supplier")
    state_number = ccn.number[1:2]
    state = get(STATE_CODES, state_number, "invalid state")
    print(io, " in $state ($state_number)")

    type_code = ccn.number[3]
    type = get(SUPPLIER_CODES, type_code, "invalid supplier type")

    sequence = parse(Int64, ccn.number[4:10])
    
    print(io, ", $type ($type_code) sequence number $sequence")
end

decode(ccn::CCN) = decode(stdout, ccn)

end # Module