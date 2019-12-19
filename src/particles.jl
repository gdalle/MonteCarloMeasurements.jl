"""
    μ ± σ

Creates $DEFAUL_NUM_PARTICLES `Particles` with mean `μ` and std `σ`.
If `μ` is a vector, the constructor `MvNormal` is used, and `σ` is thus treated as std if it's a scalar, and variances if it's a matrix or vector.
See also [`∓`](@ref), [`..`](@ref)
"""
±

"""
    μ ∓ σ

Creates $DEFAUL_STATIC_NUM_PARTICLES `StaticParticles` with mean `μ` and std `σ`.
If `μ` is a vector, the constructor `MvNormal` is used, and `σ` is thus treated as std if it's a scalar, and variances if it's a matrix or vector.
See also [`±`](@ref), [`⊗`](@ref)
"""
∓


±(μ::Real,σ) = μ + σ*Particles(DEFAUL_NUM_PARTICLES)
±(μ::AbstractVector,σ) = Particles(DEFAUL_NUM_PARTICLES, MvNormal(μ, σ))
∓(μ::Real,σ) = μ + σ*StaticParticles(DEFAUL_STATIC_NUM_PARTICLES)
∓(μ::AbstractVector,σ) = StaticParticles(DEFAUL_STATIC_NUM_PARTICLES, MvNormal(μ, σ))

"""
    a .. b

Creates $DEFAUL_NUM_PARTICLES `Particles` with mean a `Uniform` distribution between `a` and `b`.
See also [`±`](@ref), [`⊗`](@ref)
"""
(..)(a,b) = Particles(DEFAUL_NUM_PARTICLES, Uniform(a,b))

"""
    ⊗(μ,σ) = outer_product(Normal.(μ,σ))

See also [`outer_product`](@ref), [`±`](@ref)
"""
⊗(μ,σ) = outer_product(Normal.(μ,σ))

"""
    p = outer_product(dists::Vector{<:Distribution}, N=100_000)

Creates a multivariate systematic sample where each dimension is sampled according to the corresponding univariate distribution in `dists`. Returns `p::Vector{Particles}` where each Particles has a length approximately equal to `N`.
The particles form the outer product between `d` systematically sampled vectors with length given by the d:th root of N, where `d` is the length of `dists`, All particles will be independent and have marginal distributions given by `dists`.

See also `MonteCarloMeasurements.⊗`
"""
function outer_product(dists::AbstractVector{<:Distribution}, N=100_000)
    d = length(dists)
    N = floor(Int,N^(1/d))
    dims = map(dists) do dist
        v = systematic_sample(N,dist; permute=true)
    end
    cart_prod = vec(collect(Iterators.product(dims...)))
    p = map(1:d) do i
        Particles(getindex.(cart_prod,i))
    end
end

# StaticParticles(N::Integer = DEFAUL_NUM_PARTICLES; permute=true) = StaticParticles{Float64,N}(SVector{N,Float64}(systematic_sample(N, permute=permute)))


function print_functions_to_extend()
    excluded_functions = [fill, |>, <, display, show, promote, promote_rule, promote_type, size, length, ndims, convert, isapprox, ≈, <, (<=), (==), zeros, zero, eltype, getproperty, fieldtype, rand, randn]
    functions_to_extend = setdiff(names(Base), Symbol.(excluded_functions))
    for fs in functions_to_extend
        ff = @eval $fs
        ff isa Function || continue
        isempty(methods(ff)) && continue # Sort out intrinsics and builtins
        f = nameof(ff)
        if !isempty(methods(ff, (Real,Real)))
            println(f, ",")
        end
    end
end
"""
    shortform(p::AbstractParticles)
Return a short string describing the type
"""
shortform(p::Particles) = "Part"
shortform(p::StaticParticles) = "SPart"
function to_num_str(p::AbstractParticles{T}, d=3) where T
    s = std(p)
    if T <: AbstractFloat && s < eps(p)
        string(round(mean(p), sigdigits=d))
    else
        string(round(mean(p), sigdigits=d), " ± ", round(s, sigdigits=d-1))
    end
end
function Base.show(io::IO, ::MIME"text/plain", p::AbstractParticles{T,N}) where {T,N}
    sPT = shortform(p)
    print(io, "$(sPT)$N(", to_num_str(p, 4),")")
end

function Base.show(io::IO, p::AbstractParticles{T,N}) where {T,N}
    print(io, to_num_str(p, 3))
end
# function Base.show(io::IO, p::MvParticles)
#     sPT = shortform(p)
#     print(io, "(", N, " $sPT with mean ", round.(mean(p), sigdigits=3), " and std ", round.(sqrt.(diag(cov(p))), sigdigits=3),")")
# end
for mime in (MIME"text/x-tex", MIME"text/x-latex")
    @eval function Base.show(io::IO, ::$mime, p::AbstractParticles)
        print(io, "\$"); show(io, p); print("\$")
    end
end


# Two-argument functions
foreach(register_primitive_multi, [+,-,*,/,//,^,
max,min,mod,mod1,atan,atand,add_sum,hypot])
# One-argument functions
foreach(register_primitive_single, [*,+,-,/,
exp,exp2,exp10,expm1,
log,log10,log2,log1p,
sin,cos,tan,sind,cosd,tand,sinh,cosh,tanh,
asin,acos,atan,asind,acosd,atand,asinh,acosh,atanh,
zero,sign,abs,sqrt,rad2deg,deg2rad])

MvParticles(x::AbstractVector{<:AbstractArray}) = Particles(copy(reduce(hcat, x)'))

for PT in (:Particles, :StaticParticles)
    # Constructors
    @eval begin
        $PT(v::Vector) = $PT{eltype(v),length(v)}(v)
        function $PT{T,N}(n::Real) where {T,N} # This constructor is potentially dangerous, replace with convert?
            v = fill(n,N)
            $PT{T,N}(v)
        end

        """
            ℝⁿ2ℝⁿ_function(f::Function, p::AbstractArray{T})
        Applies  `f : ℝⁿ → ℝⁿ` to an array of particles.
        """
        function ℝⁿ2ℝⁿ_function(f::F, p::AbstractArray{$PT{T,N}}) where {F,T,N}
            individuals = map(1:length(p[1])) do i
                f(getindex.(p,i))
            end
            RT = promote_type(T,eltype(eltype(individuals)))
            PRT = $PT{RT,N}
            out = similar(p, PRT)
            for i = 1:length(p)
                out[i] = PRT(getindex.(individuals,i))
            end
            reshape(out, size(p))
        end

        function ℝⁿ2ℝⁿ_function(f::F, p::AbstractArray{$PT{T,N}}, p2::AbstractArray{$PT{T,N}}) where {F,T,N}
            individuals = map(1:length(p[1])) do i
                f(getindex.(p,i), getindex.(p2,i))
            end
            RT = promote_type(T,eltype(eltype(individuals)))
            PRT = $PT{RT,N}
            out = similar(p, PRT)
            for i = 1:length(p)
                out[i] = PRT(getindex.(individuals,i))
            end
            reshape(out, size(p))
        end
    end
    for ff in (var, std)
        f = nameof(ff)
        @eval function (Statistics.$f)(p::$PT{T,N},args...;kwargs...) where {T,N}
            N == 1 && (return zero(T))
            $f(p.particles, args...;kwargs...)
        end
    end
    @forward @eval($PT).particles Statistics.mean, Statistics.cov, Statistics.median, Statistics.quantile, Statistics.middle
end

function Particles(d::Distribution;kwargs...)
    Particles(DEFAUL_NUM_PARTICLES, d; kwargs...)
end

function StaticParticles(d::Distribution;kwargs...)
    StaticParticles(DEFAUL_STATIC_NUM_PARTICLES, d; kwargs...)
end

for PT in (:Particles, :StaticParticles)
    @forward @eval($PT).particles Base.iterate, Base.extrema, Base.minimum, Base.maximum

    @eval begin
        $PT{T,N}(p::$PT{T,N}) where {T,N} = p

        function $PT(m::Array{T,N}) where {T,N}
            s1 = size(m, 1)
            inds = CartesianIndices(axes(m)[2:end])
            map(inds) do ind
                $PT{T,s1}(@view(m[:,ind]))
            end
        end

        function $PT(N::Integer=DEFAUL_NUM_PARTICLES, d::Distribution{<:Any,VS}=Normal(0,1); permute=true, systematic=VS==Continuous) where VS
            if systematic
                v = systematic_sample(N,d; permute=permute)
            else
                v = rand(d, N)
            end
            $PT{eltype(v),N}(v)
        end



        function $PT(N::Integer, d::MultivariateDistribution)
            v = rand(d,N)' |> copy # For cache locality
            $PT(v)
        end

        nakedtypeof(p::$PT{T,N}) where {T,N} = $PT
        nakedtypeof(::Type{$PT{T,N}}) where {T,N} = $PT
    end
    # @eval begin

    # end
    @eval begin
        Base.length(::Type{$PT{T,N}}) where {T,N} = N
        Base.eltype(::Type{$PT{T,N}}) where {T,N} = $PT{T,N}

        Base.convert(::Type{StaticParticles{T,N}}, p::$PT{T,N}) where {T,N} = StaticParticles(p.particles)
        Base.convert(::Type{$PT{T,N}}, f::Real) where {T,N} = $PT{T,N}(fill(T(f),N))
        Base.convert(::Type{$PT{T,N}}, f::$PT{S,N}) where {T,N,S} = $PT{promote_type(T,S),N}(promote_type(T,S).(f.particles))
        function Base.convert(::Type{S}, p::$PT{T,N}) where {S<:ConcreteFloat,T,N}
            N == 1 && (return S(p[1]))
            std(p) < eps(S) || throw(ArgumentError("Cannot convert a particle distribution to a float if not all particles are the same."))
            return S(p[1])
        end
        function Base.convert(::Type{S}, p::$PT{T,N}) where {S<:ConcreteInt,T,N}
            isinteger(p) || throw(ArgumentError("Cannot convert a particle distribution to an int if not all particles are the same."))
            return S(p[1])
        end
        Base.zeros(::Type{$PT{T,N}}, dim::Integer) where {T,N} = [$PT{T,N}(zeros(eltype(T),N)) for d = 1:dim]
        Base.zero(::Type{$PT{T,N}}) where {T,N} = $PT{T,N}(zeros(eltype(T),N))
        Base.isfinite(p::$PT{T,N}) where {T,N} = isfinite(mean(p))
        Base.round(p::$PT{T,N}, r::RoundingMode, args...; kwargs...) where {T,N} = round(mean(p), r, args...; kwargs...)
        Base.round(::Type{S}, p::$PT{T,N}, args...; kwargs...) where {S,T,N} = round(S, mean(p), args...; kwargs...)
        function Base.AbstractFloat(p::$PT{T,N}) where {T,N}
            N == 1 && (return p[1])
            std(p) < eps(T) || throw(ArgumentError("Cannot convert a particle distribution to a number if not all particles are the same."))
            return p[1]
        end

        """
        union(p1::AbstractParticles, p2::AbstractParticles)

        A `Particles` containing all particles from both `p1` and `p2`. Note, this will be twice as long as `p1` or `p2` and thus of a different type.
        `pu = Particles([p1.particles; p2.particles])`
        """
        function Base.union(p1::$PT{T,NT},p2::$PT{T,NS}) where {T,NT,NS}
            $PT([p1.particles; p2.particles])
        end

        """
        intersect(p1::AbstractParticles, p2::AbstractParticles)

        A `Particles` containing all particles from the common support of `p1` and `p2`. Note, this will be of undetermined length and thus undetermined type.
        """
        function Base.intersect(p1::$PT,p2::$PT)
            mi = max(minimum(p1),minimum(p2))
            ma = min(maximum(p1),maximum(p2))
            f = x-> mi <= x <= ma
            $PT([filter(f, p1.particles); filter(f, p2.particles)])
        end

        function Base.:^(p::$PT{T,N}, i::Integer) where {T,N} # Resolves ambiguity
            res = p.particles.^i
             $PT{eltype(res),N}(res)
        end
        Base.:\(p::Vector{<:$PT}, p2::Vector{<:$PT}) = Matrix(p)\Matrix(p2) # Must be here to be most specific
    end

    @eval Base.promote_rule(::Type{S}, ::Type{$PT{T,N}}) where {S<:Number,T,N} = $PT{promote_type(S,T),N} # This is hard to hit due to method for real 3 lines down
    @eval Base.promote_rule(::Type{Bool}, ::Type{$PT{T,N}}) where {T,N} = $PT{promote_type(Bool,T),N}

    for PT2 in (:Particles, :StaticParticles)
        if PT == PT2
            @eval Base.promote_rule(::Type{$PT{S,N}}, ::Type{$PT{T,N}}) where {S,T,N} = $PT{promote_type(S,T),N}
        elseif any(==(:StaticParticles), (PT, PT2))
            @eval Base.promote_rule(::Type{$PT{S,N}}, ::Type{$PT2{T,N}}) where {S,T,N} = StaticParticles{promote_type(S,T),N}
        else
            @eval Base.promote_rule(::Type{$PT{S,N}}, ::Type{$PT2{T,N}}) where {S,T,N} = Particles{promote_type(S,T),N}
        end
    end

    @eval Base.promote_rule(::Type{<:AbstractParticles}, ::Type{$PT{T,N}}) where {T,N} = Union{}
end

Base.length(p::AbstractParticles{T,N}) where {T,N} = N
Base.ndims(p::AbstractParticles{T,N}) where {T,N} = ndims(T)
Base.:\(H::MvParticles,p::AbstractParticles) = Matrix(H)\p.particles
# Base.:\(p::AbstractParticles, H) = p.particles\H
# Base.:\(p::MvParticles, H) = Matrix(p)\H
# Base.:\(H,p::MvParticles) = H\Matrix(p)

Base.Broadcast.broadcastable(p::AbstractParticles) = Ref(p)
Base.setindex!(p::AbstractParticles, val, i::Integer) = setindex!(p.particles, val, i)
Base.getindex(p::AbstractParticles, i::Integer) = getindex(p.particles, i)
# Base.getindex(v::MvParticles, i::Int, j::Int) = v[j][i] # Defining this methods screws with show(::MvParticles)

Base.Array(p::AbstractParticles) = p.particles
Base.Vector(p::AbstractParticles) = Array(p)

function Base.Array(v::Array{<:AbstractParticles})
    m = reduce(hcat, Array.(v))
    return reshape(m, size(m, 1), size(v)...)
end
Base.Matrix(v::MvParticles) = Array(v)

# function Statistics.var(v::MvParticles,args...;kwargs...) # Not sure if it's a good idea to define this. Is needed for when var(v::AbstractArray) is used
#     s2 = map(1:length(v[1])) do i
#         var(getindex.(v,i))
#     end
#     eltype(v)(s2)
# end

Statistics.mean(v::MvParticles) = mean.(v)
Statistics.cov(v::MvParticles,args...;kwargs...) = cov(Matrix(v), args...; kwargs...)
Distributions.fit(d::Type{<:MultivariateDistribution}, p::MvParticles) = fit(d,Matrix(p)')
Distributions.fit(d::Type{<:Distribution}, p::AbstractParticles) = fit(d,p.particles)

Distributions.Normal(p::AbstractParticles) = Normal(mean(p), std(p))
Distributions.MvNormal(p::AbstractParticles) = MvNormal(mean(p), cov(p))
Distributions.MvNormal(p::MvParticles) = MvNormal(mean(p), cov(p))

meanstd(p::AbstractParticles) = std(p)/sqrt(length(p))
meanvar(p::AbstractParticles) = var(p)/length(p)

Base.:(==)(p1::AbstractParticles{T,N},p2::AbstractParticles{T,N}) where {T,N} = p1.particles == p2.particles
Base.:(!=)(p1::AbstractParticles{T,N},p2::AbstractParticles{T,N}) where {T,N} = p1.particles != p2.particles


function _comparison_operator(p)
    length(p) == 1 && return
    USE_UNSAFE_COMPARIONS[] || error("Comparison operators are not well defined for uncertain values and are currently turned off. Call `unsafe_comparisons(true)` to enable comparison operators for particles using the current reduction function $(COMPARISON_FUNCTION[]). Change this function using `set_comparison_function(f)`.")
end

function Base.:<(a::Real,p::AbstractParticles)
    _comparison_operator(p)
    a < COMPARISON_FUNCTION[](p)
end
function Base.:<(p::AbstractParticles,a::Real)
    _comparison_operator(p)
    COMPARISON_FUNCTION[](p) < a
end
function Base.:<(p::AbstractParticles, a::AbstractParticles)
    _comparison_operator(p)
    COMPARISON_FUNCTION[](p) < COMPARISON_FUNCTION[](a)
end
function Base.:(<=)(p::AbstractParticles{T,N}, a::AbstractParticles{T,N}) where {T,N}
    _comparison_operator(p)
    COMPARISON_FUNCTION[](p) <= COMPARISON_FUNCTION[](a)
end

"""
    p1 ≈ p2

Determine if two particles are not significantly different
"""
Base.:≈(p::AbstractParticles, a::AbstractParticles, lim=2) = abs(mean(p)-mean(a))/(2sqrt(std(p)^2 + std(a)^2)) < lim
Base.:≈(a::Real,p::AbstractParticles, lim=2) = abs(mean(p)-a)/std(p) < lim
Base.:≈(p::AbstractParticles, a::Real, lim=2) = abs(mean(p)-a)/std(p) < lim
Base.:≈(p::MvParticles, a::AbstractVector) = all(a ≈ b for (a,b) in zip(a,p))
Base.:≈(a::AbstractVector, p::MvParticles) = all(a ≈ b for (a,b) in zip(a,p))
Base.:≈(a::MvParticles, p::MvParticles) = all(a ≈ b for (a,b) in zip(a,p))
Base.:≉(a,b::AbstractParticles,lim=2) = !(≈(a,b,lim))
Base.:≉(a::AbstractParticles,b,lim=2) = !(≈(a,b,lim))
"""
    p1 ≉ p2

Determine if two particles are significantly different
"""
Base.:≉(a::AbstractParticles,b::AbstractParticles,lim=2) = !(≈(a,b,lim))

Base.sincos(x::AbstractParticles) = sin(x),cos(x)
Base.minmax(x::AbstractParticles,y::AbstractParticles) = (min(x,y), max(x,y))

Base.:!(p::AbstractParticles) = all(p.particles .== 0)

Base.isinteger(p::AbstractParticles) = all(isinteger, p.particles)
Base.iszero(p::AbstractParticles) = all(iszero, p.particles)
Base.iszero(p::AbstractParticles, tol) = abs(mean(p.particles)) < tol

≲(a,b,args...) = a < b
≲(a::Real,p::AbstractParticles,lim=2) = (mean(p)-a)/std(p) > lim
≲(p::AbstractParticles,a::Real,lim=2) = (a-mean(p))/std(p) > lim
≲(p::AbstractParticles,a::AbstractParticles,lim=2) = (mean(p)-mean(a))/(2sqrt(std(p)^2 + std(a)^2)) > lim
≳(a::Real,p::AbstractParticles,lim=2) = ≲(p,a,lim)
≳(p::AbstractParticles,a::Real,lim=2) = ≲(a,p,lim)
≳(p::AbstractParticles,a::AbstractParticles,lim=2) = ≲(a,p,lim)
Base.eps(p::Type{<:AbstractParticles{T,N}}) where {T,N} = eps(T)
Base.eps(p::AbstractParticles{T,N}) where {T,N} = eps(T)
Base.eps(p::AbstractParticles{<:Complex{T},N}) where {T,N} = eps(T)

"""
    norm(x::AbstractParticles, p=2)

if p == 2: return abs(mean(x))
elseif p == Inf: return max(extrema(x)...)
"""
function LinearAlgebra.norm(x::AbstractParticles, p::Union{AbstractFloat, Integer}=2)
    if p == 2
        return abs(mean(x))
    elseif p == Inf
        return max(extrema(x)...)
    end
    throw(ArgumentError("Cannot take $(p)-norm of particles"))
end





Base.exp(p::AbstractMatrix{<:AbstractParticles}) = ℝⁿ2ℝⁿ_function(exp, p)
LinearAlgebra.lyap(p1::Matrix{<:AbstractParticles}, p2::Matrix{<:AbstractParticles}) = ℝⁿ2ℝⁿ_function(lyap, p1, p2)


# OBS: defining this was a very bad idea, eigvals jump around and get confused with each other etc.
# function LinearAlgebra.eigvals(p::Matrix{$PT{T,N}}) where {T,N} # Special case to propte types differently
#     individuals = map(1:length(p[1])) do i
#         eigvals(getindex.(p,i))
#     end
#
#     PRT = Complex{$PT{T,N}}
#     out = Vector{PRT}(undef, length(individuals[1]))
#     for i = eachindex(out)
#         c = getindex.(individuals,i)
#         out[i] = complex($PT{T,N}(real(c)),$PT{T,N}(imag(c)))
#     end
#     out
# end
