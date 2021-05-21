# primitive types = :ComputedObject, :Element, :Collection
# do not touch primitives, creating using @pytype usually results in unexpected behavior

types = [
    :ComputedObject,
    :Element,
    :Collection,
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

for type in types
    @eval begin
        @pytype $(type) ()->ee.$(type)
    end
end