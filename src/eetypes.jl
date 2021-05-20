# primitive types = :ComputedObject, :Element, :Collection
# do not touch primitives, usually result in unexpected behavior

types = [
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
    :Element,
    :ComputedObject,
    :Collection
]

for type in types
    @eval begin
        @pytype $(type) ()->ee.$(type)
    end
end