# This file defines the EarthEngine types 

# list of main earthengine types
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
    :Reducer,
]

# primitive types that other types inherit from
basetypes = [:Collection, :Element, :ComputedObject, :Function]

# concat types together in one vector
# order matters!!! basetypes have to be after everything else
types = vcat(psuedotypes, maintypes, basetypes)

# create the Julia types from Python objects
for type in types
    @eval begin
        @pytype $(type) () -> ee.$(type)
    end
end

# define helper constructor for empty types that wrap more cryptic constructors
# this allows users to simply call EE.Type() to get a type value without having to provide inputs
# empty constructors for base types
EarthEngine.ComputedObject() = EarthEngine.ComputedObject("", "")
EarthEngine.Element() = EarthEngine.Element("", "")
EarthEngine.Collection() = EarthEngine.Collection("", "")

# empty constructors for psuedo types
EarthEngine.Reducer() = EarthEngine.Reducer(EarthEngine.ComputedObject())
EarthEngine.Array() = EarthEngine.Array([])
EarthEngine.Blob() = EarthEngine.Blob("")
EarthEngine.DateRange() = EarthEngine.DateRange("", "")
EarthEngine.Classifier() = EarthEngine.Classifier(EarthEngine.ComputedObject())
EarthEngine.Clusterer() = EarthEngine.Clusterer(EarthEngine.ComputedObject())
EarthEngine.ConfusionMatrix() = EarthEngine.ConfusionMatrix("")
EarthEngine.ErrorMargin() = EarthEngine.ErrorMargin(NaN)
EarthEngine.Join() = EarthEngine.Join(EarthEngine.ComputedObject())
EarthEngine.Kernel() = EarthEngine.Kernel(EarthEngine.ComputedObject())
EarthEngine.Model() = EarthEngine.Model(EarthEngine.ComputedObject())
EarthEngine.PixelType() = EarthEngine.PixelType(EarthEngine.ComputedObject())
EarthEngine.Projection() = EarthEngine.Projection(EarthEngine.ComputedObject())

# empty constructors for main types
EarthEngine.Date() = EarthEngine.Date("")
EarthEngine.List() = EarthEngine.List([])
EarthEngine.Geometry() = EarthEngine.Geometry(Point(NaN, NaN))
EarthEngine.Feature() = EarthEngine.Feature(EarthEngine.Geometry())
EarthEngine.FeatureCollection() = EE.FeatureCollection([])
EarthEngine.ImageCollection() = EarthEngine.ImageCollection("")
EarthEngine.String() = EarthEngine.String("")
EarthEngine.Number() = EarthEngine.Number(NaN)
