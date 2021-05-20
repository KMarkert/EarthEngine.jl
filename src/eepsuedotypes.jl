types = [
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

for type in types
    @eval begin
        @pytype $(type) ()->ee.$(type)
    end
end