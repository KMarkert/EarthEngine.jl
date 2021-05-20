__precompile__(true)

module EE

using PyCall
using Lazy
import Base: 
    length, keys, contains, split, 
    replace, lowercase, string, filter, 
    union, size, identity, map


const module_dir = @__DIR__

# define a constant pointer to the ee object
const ee = PyNULL()

function __init__()
    try 
        copy!(ee, pyimport("ee"))
    catch err
        error("The `earthengine-api` package could not be imported. You must install the Python earthengine-api before using this package. The error was $err")
    end

end

version() = VersionNumber(ee.__version__)

const pre_type_map = []


# Maps a python object corresponding to an EE class to a Julia type which
# wraps that class.
const type_map = Dict()

abstract type EEWrapped end

PyCall.PyObject(x::EEWrapped) = x.pyo

macro pytype(name, class)
    quote
        struct $(name) <: EEWrapped
            pyo::PyObject
            $(esc(name))(pyo::PyObject) = new(pyo)
            function $(esc(name))(args...; kwargs...)
                ee_method = ($class)()
                new(pycall(ee_method, PyObject, args...; kwargs...))
            end
        end

        # This won't work until PyCall is updated to support
        # the Julia 1.0 iteration protocol.
        function Base.iterate(x::$name, state...)
            res = Base.iterate(x.pyo, state...)
            if res === nothing
                return nothing
            else
                value, state = res
                return ee_wrap(value), state
            end
        end

        push!(pre_type_map, ($class, $name))
    end
end

function ee_wrap(pyo::PyObject)
    for (pyt, pyv) in type_map
        pyt === nothing && continue
        if pyisinstance(pyo, pyt)
            return pyv(pyo)
        end
    end
    return convert(PyAny, pyo)
end


quot(x) = Expr(:quote, x)

ee_wrap(x::Union{AbstractArray, Tuple}) = [ee_wrap(_) for _ in x]

ee_wrap(pyo) = pyo

fix_arg(x) = x

pyattr(class, method) = pyattr(class, method, method)

function pyattr(class, jl_method, py_method)
    quote
        function $(esc(jl_method))(pyt::$class, args...; kwargs...)
            new_args = fix_arg.(args)
            method = pyt.pyo.$(string(py_method))
            pyo = pycall(method, PyObject, new_args...; kwargs...)
            wrapped = ee_wrap(pyo)
        end
    end
end

macro pyattr(class, method)
    pyattr(class, method)
end

macro pyattr(class, method, orig_method)
    pyattr(class, method, orig_method)
end

"""
    pyattr_set(types, methods...)
For each Julia type `T<:EEWrapped` in `types` and each method `m` in `methods`,
define a new function `m(t::T, args...)` that delegates to the underlying
pyobject wrapped by `t`.
"""
function pyattr_set(classes, methods...)
    for class in classes
        for method in methods
            @eval @pyattr($class, $method)
        end
    end
end

const ee_exports = []

function Initialize(args...; kwargs...)    
    try
        ee.Initialize(args...; kwargs...)
    catch err
        error("Could not initialize an `ee` session. Please try authenticating the earthengine-api.")
    end
    
    include("$(module_dir)/eepsuedotypes.jl")
    include("$(module_dir)/eefuncs.jl") 

    for f in Symbol.(ee_exports)
        @eval export $f
    end
end

function Authenticate(args...; kwargs...)
    try
        ee.Autheticate(args...; kwargs...)
    catch err
        error("Could not run authetication workflow... Please try authenticating manually using the earthengine-api CLI (i.e. `\$ earthengine autheticate`")
    end
end

include("eetypes.jl")

export ee, Initialize, Authenticate

end # module
