module NLsolve


import Base.show,
       Base.push!,
       Base.getindex,
       Base.setindex!

export DifferentiableMultivariateFunction,
       nlsolve


immutable DifferentiableMultivariateFunction
    f!::Function
    g!::Function
    fg!::Function
end

function DifferentiableMultivariateFunction(f!::Function, g!::Function)
    function fg!(x::Vector, fx::Vector, gx::Array)
        f!(x, fx)
        g!(x, gx)
    end
    return DifferentiableMultivariateFunction(f!, g!, fg!)
end

immutable SolverState
    iteration::Int
    fnorm::Float64
    stepnorm::Float64
    metadata::Dict
end

function SolverState(i::Integer, fnorm::Real)
    SolverState(int(i), float64(fnorm), NaN, Dict())
end

function SolverState(i::Integer, fnorm::Real, stepnorm::Real)
    SolverState(int(i), float64(fnorm), float64(stepnorm), Dict())
end

immutable SolverTrace
    states::Vector{SolverState}
end

SolverTrace() = SolverTrace(Array(SolverState, 0))

function Base.show(io::IO, t::SolverState)
    @printf io "%6d   %14e   %14e\n" t.iteration t.fnorm t.stepnorm
    if !isempty(t.metadata)
        for (key, value) in t.metadata
            @printf io " * %s: %s\n" key value
        end
    end
    return
end

Base.push!(t::SolverTrace, s::SolverState) = push!(t.states, s)

Base.getindex(t::SolverTrace, i::Integer) = getindex(t.states, i)

function Base.setindex!(t::SolverTrace,
                        s::SolverState,
                        i::Integer)
    setindex!(t.states, s, i)
end

function Base.show(io::IO, t::SolverTrace)
    @printf io "Iter     f(x) inf-norm    Step 2-norm \n"
    @printf io "------   --------------   --------------\n"
    for state in t.states
        show(io, state)
    end
    return
end

function update!(tr::SolverTrace,
                 iteration::Integer,
                 fnorm::Real,
                 stepnorm::Real,
                 dt::Dict,
                 store_trace::Bool,
                 show_trace::Bool)
    ss = SolverState(iteration, fnorm, stepnorm, dt)
    if store_trace
        push!(tr, ss)
    end
    if show_trace
        show(ss)
    end
    return
end

type SolverResults{T}
    method::ASCIIString
    initial_x::Vector{T}
    zero::Vector{T}
    residual_norm::Float64
    iterations::Int
    x_converged::Bool
    xtol::Float64
    f_converged::Bool
    ftol::Float64
    trace::SolverTrace
    f_calls::Int
    g_calls::Int
end

function converged(r::SolverResults)
    return r.x_converged || r.f_converged
end

function Base.show(io::IO, r::SolverResults)
    @printf io "Results of Nonlinear Solver Algorithm\n"
    @printf io " * Algorithm: %s\n" r.method
    @printf io " * Starting Point: %s\n" string(r.initial_x)
    @printf io " * Zero: %s\n" string(r.zero)
    @printf io " * Inf-norm of residuals: %f\n" r.residual_norm
    @printf io " * Iterations: %d\n" r.iterations
    @printf io " * Convergence: %s\n" converged(r)
    @printf io "   * |x - x'| < %.1e: %s\n" r.xtol r.x_converged
    @printf io "   * |f(x)| < %.1e: %s\n" r.ftol r.f_converged
    @printf io " * Function Calls (f): %d\n" r.f_calls
    @printf io " * Jacobian Calls (df/dx): %d" r.g_calls
    return
end


function assess_convergence(x::Vector,
                            x_previous::Vector,
                            f::Vector,
                            xtol::Real,
                            ftol::Real)
    x_converged, f_converged = false, false

    if norm(x - x_previous, Inf) < xtol
        x_converged = true
    end

    if norm(f, Inf) < ftol
        f_converged = true
    end

    converged = x_converged || f_converged

    return x_converged, f_converged, converged
end

include("newton.jl")

function nlsolve(df::DifferentiableMultivariateFunction,
                 initial_x::Vector;
                 xtol::Real = 0.0,
                 ftol::Real = 1e-8,
                 iterations::Integer = 1_000,
                 store_trace::Bool = false,
                 show_trace::Bool = false,
                 extended_trace::Bool = false)
    if extended_trace
        show_trace = true
    end
    if show_trace
        @printf "Iter     f(x) inf-norm    Step 2-norm \n"
        @printf "------   --------------   --------------\n"
    end
    newton(df, initial_x, xtol, ftol, iterations,
           store_trace,
           show_trace,
           extended_trace)
end

end # module