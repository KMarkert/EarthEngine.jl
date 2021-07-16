# this file create julia functions from the python modules

empty!(type_map)  # for behaving nicely in system image

for (ee_expr, julia_type) in pre_type_map
    type_map[ee_expr()] = julia_type
end

# first loop over the ee types and set functions that take type
for key in collect(keys(type_map))
    # get list of methods
    methods = py"dir"(key)
    # loop over all methods and create julia methods
    for method in methods
        if ~startswith(method, "_")
            pyattr_set([type_map[key]], Symbol(method))
            if ~(method in ee_exports)
                push!(ee_exports, method)
            end
        end
    end
end


# next get methods from the individual modules
# outer loop is to get the methods for each module
# inner loop is to map the methods from module to julia funcs

modules = [
    :Array,
    :Classifier,
    :Clusterer,
    :ConfusionMatrix,
    :Date,
    :DateRange,
    :Dictionary,
    :ErrorMargin,
    :Feature,
    :FeatureCollection,
    :Filter,
    :Geometry,
    :Image,
    :ImageCollection,
    :Join,
    :Kernel,
    :List,
    :Model,
    :Number,
    :PixelType,
    :Projection,
    :Reducer,
    :String,
    :Terrain,
    :data,
]

mod_methods = OrderedDict()

# loop over the modules
for mod in modules
    # get the module functions and add to dict
    @eval submethods = collect(py"dir"(ee.$(string(mod))))

    # loop over the module methods
    for submethod in submethods
        submethod = convert(AbstractString, submethod)
        # check if submethod is not private
        if ~startswith(submethod, "_")
            m = Symbol(submethod)
            # create a julia function of the public methods
            @eval begin
                function $m(args...; kwargs...)
                    method = ee.$(string(mod)).$(submethod)
                    result = pycall(method, PyObject, args...; kwargs...)
                    ee_wrap(result)
                end
            end
            # add to list of methods for module export
            if ~(submethod in ee_exports)
                push!(ee_exports, submethod)
            end
        end
    end
end

# for some reason the ee.Algorithms module is a Dict....why???
# function to recusively search though the ee.Algorithms module and wrap all python functions
function wrap_eealgorithms(dict)
    for (k, v) in dict
        if typeof(v) == PyCall.PyObject
            m = Symbol(k)
            @eval begin
                function $m(args...; kwargs...)
                    method = $v
                    result = pycall(method, PyObject, args...; kwargs...)
                    ee_wrap(result)
                end
            end
            # add to list of methods for module export
            if ~(k in ee_exports)
                push!(ee_exports, k)
            end
        else
            wrap_eealgorithms(v)
        end
    end
end

# get the dict of ee algorithms
algorithms_dict = ee.Algorithms
# remove the GeometryConstructors functions that clobber with others
delete!(algorithms_dict, "GeometryConstructors")

# apply recusive wrapping
wrap_eealgorithms(algorithms_dict)


# define dispatch signatures for Mathematical Operations
# from https://docs.julialang.org/en/v1/manual/mathematical-operations/#Bitwise-Operators
# arithmetic operators
Base.:+(x::AbstractEEObject,y::AbstractEEObject) = add(x,y)
Base.:-(x::AbstractEEObject,y::AbstractEEObject) = subtract(x,y)
Base.:*(x::AbstractEEObject,y::AbstractEEObject) = multiply(x,y)
Base.:/(x::AbstractEEObject,y::AbstractEEObject) = divide(x,y)
Base.:÷(x::AbstractEEObject,y::AbstractEEObject) = toInt(divide(x,y))
Base.:\(x::AbstractEEObject,y::AbstractEEObject) = divide(y,x)
Base.:^(x::AbstractEEObject,y::AbstractEEObject) = pow(x,y)
Base.:%(x::AbstractEEObject,y::AbstractEEObject) = mod(x,y)

# bitwise pperators
Base.:~(x::AbstractEEObject) = bitwiseNot(x)
Base.:&(x::AbstractEEObject,y::AbstractEEObject) = bitwiseAnd(x,y)
Base.:|(x::AbstractEEObject,y::AbstractEEObject) = bitwiseOr(x,y)
Base.:⊻(x::AbstractEEObject,y::AbstractEEObject) = bitwiseXor(x,y)
Base.:>>(x::AbstractEEObject,y::AbstractEEObject) = rightShift(x,y)
Base.:<<(x::AbstractEEObject,y::AbstractEEObject) = leftShift(x,y)

# numeric comparisons
# Base.:==(x::AbstractEEObject,y::AbstractEEObject) = eq(x,y)
# Base.:!=(x::AbstractEEObject,y::AbstractEEObject) = neq(x,y)
# Base.:≠(x::AbstractEEObject,y::AbstractEEObject) = neq(x,y)
# Base.isless(x::AbstractEEObject,y::AbstractEEObject) = lt(x,y)
# Base.:<(x::AbstractEEObject,y::AbstractEEObject) = lt(x,y)
# Base.:≤(x::AbstractEEObject,y::AbstractEEObject) = lte(x,y)
# Base.:<=(x::AbstractEEObject,y::AbstractEEObject) = lte(x,y)
# Base.:>(x::AbstractEEObject,y::AbstractEEObject) = gt(x,y)
# Base.:≥(x::AbstractEEObject,y::AbstractEEObject) = gte(x,y)
# Base.:>=(x::AbstractEEObject,y::AbstractEEObject) = gte(x,y)
