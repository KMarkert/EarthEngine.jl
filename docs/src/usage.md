# EE.jl Usage

This document serves to illustrate and discuss some of the internals and interesting bits when using the `EE.jl` Julia API. 

The Julia API imports the majority of the functions from the Python API (currently missing the modules in `ee.Algorithms`...). The functions lose the `ee.Type` syntax so the one can simply call the methods by name and not have as much code. For example `ee.Reducer.histogram()` is simply `histogram()` in the Julia API. There are multiple versions of some methods depending on the ee.Type (like `mean()`) and the differences get handled by Julia's multiple dispatch, see [Leveraging Julia's multiple distpatch](#Leveraging-Julia's-multiple-distpatch) section for details.

Another notable difference is how methods are called. For example, if you would like to filter an ImageCollection and then reduce an Image, the syntax changes from `imagecollection.filterDate(start,end).mean()` to `mean(filterDate(imagecollection, start, end))`. This makes the syntax more like native Julia syntax and not object oriented. If you like the Python API of interfacing with EE or want to easily convert your Python code to Julia, then see the [Using the Python API through Julia section](#Using-the-Python-API-through-Julia).

## EE Types

One nice feature of  Julia is that it supports [types](https://docs.julialang.org/en/v1/manual/types/). This allows for easily creating user defined fucntions and code that are [type safe](https://en.wikipedia.org/wiki/Type_safety). 

The Julia types are are one-to-one mapping of the Earth Engine types such as Image, Feature, etc. One can access EE types using the following code: `EE.Image` (note the capitalized EE). These types are not to be confused with `ee.Image` which is the original Python object.

```julia
typeof(ee.Image)
# returns PyCall.PyObject

typeof(EE.Image)
# returns DataType
```

Consider the following example where we define a function that takes an `EE.Image` type as an input and returns an `EE.Image` type. This function will return an error if provided any other variable with a type that is not an `EE.Image`. Here is the following code:

```julia
# define a function that expects an EE.Image as input and returns EE.Image
function ndvi(img::EE.Image)
    return normalizedDifference(img, ["B5","B4"])
end

# get an Image and calculate a FeatureCollection
img = EE.Image("LANDSAT/LC08/C01/T1_TOA/LC08_033032_20170719")
fc = EE.FeatureCollection(sample(img;scale=30,numPixels=500))

# works
ndvi(img)
# returns: EE.ComputedObject(PyObject <ee.image.Image object at ...>)

# does not work
ndvi(fc)
#ERROR: MethodError: no method matching ndvi(::EE.FeatureCollection)
#Closest candidates are:
#  ndvi(::EE.Image) at REPL[XX]:1
```

Again, this allows users to create type safe user defined functions. This also allows users to take advantage of Julia's amazing [multiple dispatch](https://en.wikipedia.org/wiki/Multiple_dispatch) feature.

## Leveraging Julia's multiple distpatch

Julia's multiple dispatch is a powerful feature that allows users to define multiple functions with the same name but have different functionality depending on the type. Building off of our previous example of calculating NDVI, here we are going to define additional functions called `ndvi` that perform computations on different types within a workflow:

```julia
# define an ndvi function to calculate for EE.FeatureCollection
function ndvi(fc::EE.FeatureCollection)
    # map the ndvi-feature function over the fc
    return map(fc,ndvi)
end

# define ndvi function to calculate from two Numbers
function ndvi(nir::EE.Number,red::EE.Number)
    # compute ndvi from numbers
    return divide(subtract(nir,red),add(nir,red))
end

# define an ndvi function to calculate for EE.Feature
function ndvi(f)
    f = EE.Feature(f)
    r = EE.Number(get(f,"B4"))
    n = EE.Number(get(f,"B5"))
    # apply ndvi-number function
    val = ndvi(n,r)
    return set(f,"ndvi",val)
end

# input a FeatureCollection into ndvi
ndvi_fc = ndvi(fc)
# returns: EE.FeatureCollection(PyObject <ee.featurecollection.FeatureCollection object at ...>)
```

If you are used to Python then this code should not work (at least not return a FeatureCollection). We clearly defined `ndvi` multiple times and the last definition should not work with a FeatureCollection...so how does it work!? This is the power of multiple dispatch! By providing types Julia is able to determine which function to use depending on the input values.

We can check the different signatures of the function `ndvi` with the following code:

```julia
# check the signatures of `ndvi`
methods(ndvi)
# # 4 methods for generic function "ndvi":
# [1] ndvi(img::EE.Image) in Main at REPL[XX]:2
# [2] ndvi(fc::EE.FeatureCollection) in Main at REPL[XX]:2
# [3] ndvi(nir::EE.Number, red::EE.Number) in Main at REPL[XX]:2
# [4] ndvi(f) in Main at REPL[XX]:2
```

If you are interested in learning more about mulitple dispatch, then pleae see the following presentation: [The Unreasonable Effectiveness of Multiple Dispatch](https://www.youtube.com/watch?v=kc9HwsxE1OY) by Stefan Karpinski.

## Quirks

### Be careful with types

Sometimes functions do not return the same type as the input, this can cause issues in the downstream processing when Julia tries to figure out which method signature to use. Take the following example, where we have an ImageCollection, filter the collection:

```julia
ic = EE.ImageCollection("LANDSAT/LT05/C01/T1_SR")
filtered = filterDate(ic,"2000-01-01","2000-02-01")
# returns: EE.Collection(PyObject <ee.imagecollection.ImageCollection object at ...>)
```

This returns an `EE.Collection` (which is techically a parent type of `EE.ImageCollection`) but will cause issues/unexpected behavior when trying to use the resulting variable in subsequent functions.

A simple solution to this is to cast the result after filtering to an `EE.ImageCollection` and proceed as in the following code:

```julia
filtered = EE.ImageCollection(filterDate(ic,"2000-01-01","2000-02-01"))
# returns: EE.ImageCollection(PyObject <ee.imagecollection.ImageCollection object at ...>)
```

When in doubt, cast the varible to the EE.type that you would like.

### Constructors with multiple dispatch

Due to Juia's multiple dispathcing based on type sometime you will have to provide a type as the first argument into a constructor method for an EE object. For example, the function `gt()` has multiple uses: you can compared Images, Arrays, Numbers, etc. but there is also an `EE.Filter` constructor that `gt()`. If you try to create a filter using the keyword arguments as inputs such as `gt(;name="B4",value=0.05)` you will get an error because Julia cannot figure out which signature to use. To overcome this one can simply provide a blank object of the desired type as in below:

```julia
filter = gt(EE.Filter(); name="B4", value=0.05)
```

When in doubt, you can always provide the EE.Type as the first argument when creating a new object (i.e. `constant(EE.Image(),1)`). If you are using an object, Julia will determine which method signature to use and which type to provide it, i.e. `gt(random(),0.5)` will return an image.

While this works most of the time, this fails with methods that create types with multiple signatures.  This is because currently the Python Reducer object does not have an internal constructor so when no data is provided it throws an error. See the below example:

```julia
# works
# no other method for histogram other than for Reducer
histogram()
# output: EE.ComputedObject(PyObject <ee.Reducer object at ...>)

# does not work
# cannot determine which signature to use
toList()

# does not work
# Reducer constructor yields and error
toList(EE.Reducer()) 
```

To overcome this challenge one can simply wrap the object from the Python API in a Julia quivalent type as in the following example:

```julia
EE.Reducer(ee.Reducer.toList())
#output: EE.Reducer(PyObject <ee.Reducer object at ...>)
```

There are more likely than not more quirks in using the EE API this way, if there is a question or some unexpected behavior please file an [issue on the GitHub repo](https://github.com/KMarkert/EE.jl/issues)


## Using the Python API through Julia

The `EE.jl` package also exposes the `ee` Python module so one can use the same code as one would when programming in Python. See the following example of valid Julia and Python code:

```julia
# import the EE package and initialize an ee session
# this is the only non-Python
using EE
Initialize()

# now we can access the `ee` module like we would with Python
dem = ee.Image("USGS/SRTMGL1_003");
xy = ee.Geometry.Point(86.9250, 27.9881);
value = dem.sample(xy,scale=30).first().get("elevation")
println(value.getInfo())
# 8729 
```

Accessing the EE API this way is *an exact* match to the Python API so one can simply copy-paste whatever Python code you have using the `ee` module and it will work with this Julia API.
