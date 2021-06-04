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
        # check if submethod is not private
        if ~startswith(submethod, "_")
            m = Symbol(submethod) 
            # create a julia function of the public methods
            @eval begin
                function $m(args...; kwargs...)
                    method = ee.$string(mod).$(string(submethod))
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
