empty!(type_map)  # for behaving nicely in system image


for (ee_expr, julia_type) in pre_type_map
    type_map[ee_expr()] = julia_type
end

# first loop over the ee types and set functions that take type
for key in collect(keys(type_map))
    methods = py"dir"(key)
    # println(key,methods)
    for method in methods
        if ~startswith(method, "_")
            # println(key,method)
            pyattr_set([type_map[key]], Symbol(method))
            if ~(method in ee_exports)
                push!(ee_exports,method)
            end
        end
    end
end


# next do two passes on the individual modules
# first pass is to get the methods
# second pass is to map the methods to julia funcs

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
    :data
] 

mod_methods = Dict()

for mod in modules
    @eval begin
        submethods = collect(py"dir"(ee.$(string(mod))))
        # get the terrain module functions
        mod_methods[$(string(mod))] = submethods
    end
end

for (k,v) in mod_methods
    for submethod in v
        if ~startswith(submethod,"_")
            m = Symbol(submethod)
            @eval begin 
                function $m(args...; kwargs...)
                    method = ee.$k.$(string(submethod))
                    result = pycall(method, PyObject, args...; kwargs...)
                    ee_wrap(result)
                end
            end
            if ~(submethod in ee_exports)
                push!(ee_exports,submethod)
            end
        end
    end
end


# the modules that still need to be wrapped
# Algorithms:
#     CannyEdgeDetector
#     Describe
#     ProjectionTransform
#     CrossCorrelation
#     HillShadow
#     HoughTransform
#     ObjectType
#     If
#     IsEqual
#     Terrain

# FMask:

# Image.Segmentation:

# TemporalSegmentation:

# Landsat:

# Sentinel2:
