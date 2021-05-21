__precompile__(true)

module EE

using PyCall
import Base: 
    length, keys, contains, split, 
    replace, lowercase, string, filter, 
    union, size, identity, map, first,
    get, repeat


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

"""
    @pytype name class

Macro for creating a Julia Type that wraps a PyObject class
"""
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

"""
    ee_wrap(pyo::PyObject)

Function for wrapping a Python object defined in the type map
"""
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


"""
    pyattr(class method orig_method)

Function for creating a method signature for a Julia Type
In Python world method(T::class) is analagous to class.method()
"""
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


"""
    @pyattr class method

Macro for creating a method signature for a Julia Type
In Python world method(T::class) is analagous to class.method()
"""
macro pyattr(class, method)
    pyattr(class, method)
end


"""
    @pyattr class method orig_method

Macro for creating a method signature for a Julia Type
In Python world method(T::class) is analagous to class.method()
This will create a new method name which calls the orig_method
"""
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

"""
    Initialize(args...; kwargs...)

Function to initialize an EarthEngine session (analagous to ee.Initialize() from
the Python API). Accepts arguments and keywords from the Python ee.Initialize()
function. This function also dynamically builds the EE API and creates the methods 
with signatures for each EE Type.
"""
function Initialize(args...; kwargs...)    
    try
        ee.Initialize(args...; kwargs...)
    catch err
        error("Could not initialize an `ee` session. Please try authenticating the earthengine-api.")
    end
    
    # pull in the types and dynamically wrap things after initialization
    include("$(module_dir)/eepsuedotypes.jl")
    include("$(module_dir)/eefuncs.jl") 

    for f in Symbol.(ee_exports)
        @eval export $f
    end
end

"""
    Authenticate()

Function to execute the EarthEngine authetication workflow (analgous to 
ee.Authenticate() in the Python API). This function should only be executed
once if the EE API has not be used before.
"""
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
