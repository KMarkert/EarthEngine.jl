# This file defines the EarthEngine types 

# main 
maintypes = [
    :Number,
    :String,
    :Image,
    :Feature,
    :ImageCollection,
    :FeatureCollection,
    :Date,
    :List,
    :Filter,
    :Geometry,
    :Dictionary,
]

# types that get defined on-the-fly during Initialization
psuedotypes = [
    :Array,
    :Blob,
    :DateRange,
    :Classifier,
    :Clusterer,
    :ConfusionMatrix,
    :ErrorMargin,
    :Join,
    :Kernel,
    :Model,
    :PixelType,
    :Projection,
    :Reducer
]

# primitive types that other types inherit from
basetypes = [
    :Collection,
    :Element,
    :ComputedObject,
]

# concat types together in one vector
# order matters!!! basetypes have to be after everything else
types = vcat(maintypes, psuedotypes, basetypes)

# create the Julia types from Python objects
for type in types
    @eval begin
        @pytype $(type) ()->ee.$(type)
    end
end
