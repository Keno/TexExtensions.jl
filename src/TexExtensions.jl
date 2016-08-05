isdefined(Base, :__precompile__) && __precompile__()

module TexExtensions

using Compat

@compat import Base.show

@Base.Multimedia.textmime "text/mathtex+latex"

const tm = MIME("text/mathtex+latex")
const T = MIME"text/mathtex+latex"

@compat function show(io::IO, ::T, x::AbstractString)
    write(io,"\\text{")
    write(io,x)
    write(io,"}")
end

@compat function show(io::IO, ::T, x::Rational)
    write(io,"\\frac{")
    show(io,tm,x.num)
    write(io,"}{")
    show(io,tm,x.den)
    write(io,"}")
end

# This code is largely copied from grisu.jl, we really should have to copy this mutch

_writefloat(io::IO, x::AbstractFloat, mode::Int32, n::Int, t) =
    _writefloat(io, x, mode, n, t, "NaN", "Inf")
_writefloat(io::IO, x::Float32, mode::Int32, n::Int, t) =
    _writefloat(io, x, mode, n, t, "NaN32", "Inf32")
_writefloat(io::IO, x::Float16, mode::Int32, n::Int, t) =
    _writefloat(io, x, mode, n, t, "NaN16", "Inf16")

function _writefloat(io::IO, x::AbstractFloat, mode::Int32, n::Int, typed, nanstr, infstr)
    if isnan(x) return write(io, "\\text{", typed ? nanstr : "NaN","}"); end
    if isinf(x)
        if x < 0 write(io,"\{\}-") end
        write(io, "\\infty")
        return
    end
    if typed && isa(x,Float16) write(io, "\\text{float16("); end
    len, pt, neg, pdigits = grisu_fmt(x, mode, n)
    if mode == Base.Grisu.PRECISION
        while len > 1 && Base.Grisu.DIGITS[len] == '0'
            len -= 1
        end
    end
    # Make sure latex understands this is negations
    if neg write(io,"\{\}-") end
    if pt <= -4 || pt > 6 # .00001 to 100000.
        # => #.#######e###
        write(io, pdigits, 1)
        write(io, '.')
        if len > 1
            write(io, pdigits+1, len-1)
        else
            write(io, '0')
        end
        write(io, "\\times 10^{",dec(pt-1),"}")
        if typed && isa(x,Float16)
            write(io, ")\\}")
        end
        return
    elseif pt <= 0
        # => 0.00########
        write(io, "0.")
        while pt < 0
            write(io, '0')
            pt += 1
        end
        write(io, pdigits, len)
    elseif pt >= len
        # => ########00.0
        write(io, pdigits, len)
        while pt > len
            write(io, '0')
            len += 1
        end
        write(io, ".0")
    else # => ####.####
        write(io, pdigits, pt)
        write(io, '.')
        write(io, pdigits+pt, len-pt)
    end
    if typed && isa(x,Float16) write(io, ")\\}"); end
    nothing
end

if VERSION < v"0.4-dev"
    eval(quote
        function grisu_fmt(x, mode, n)
            @Base.Grisu.grisu_ccall x mode n
            pdigits = pointer(Base.Grisu.DIGITS)
            neg = Base.Grisu.NEG[1]
            len = int(Base.Grisu.LEN[1])
            pt  = int(Base.Grisu.POINT[1])
            len, pt, neg, pdigits
        end
    end)
else
    grisu_fmt(x, mode, n) = Base.Grisu.grisu(x, mode, n)
end

@compat function show(io::IO, ::T, x::BigFloat)
    e = Array(Culong,1)
    str = ccall((:mpfr_get_str,:libmpfr),Ptr{UInt8},(Ptr{UInt8},Ptr{Culong},Cint,Csize_t,Ptr{Void},Int32),C_NULL,e,
        10,0,&x,Base.MPFR.ROUNDING_MODE[end])
    ret = bytestring(str)
    ccall((:mpfr_free_str,:libmpfr),Void,(Ptr{UInt8},),str)
    if ret[1] == '-'
        radix = 2
    else
        radix = 1
    end
    write(io,ret[1:radix])
    write(io,'.')
    write(io,ret[(radix+1):end])
    write(io, "\\times 10^{",dec(e[1]),"}")
end

@compat show(io::IO, ::T, x::Float64) = _writefloat(io, x, Base.Grisu.SHORTEST, 0, true)
@compat show(io::IO, ::T, x::Float32) = _writefloat(io, x, Base.Grisu.SHORTEST_SINGLE, 0, true)
@compat show(io::IO, ::T, x::Float16) = _writefloat(io, x, Base.Grisu.PRECISION, 4, true)

@compat show(io::IO, ::T, x::Integer) = show(io,x)

end # module
