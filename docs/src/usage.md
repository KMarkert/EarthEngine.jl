# EarthEngine.jl Usage

This document serves to illustrate and discuss some of the internals and interesting bits when using the `EarthEngine.jl` Julia API. 

The Julia API imports the majority of the functions from the Python API (currently missing the modules in `ee.Algorithms`...). The functions lose the `ee.Type` syntax so the one can simply call the methods by name and not have as much code. For example `ee.Reducer.histogram()` is simply `histogram()` in the Julia API. There are multiple versions of some methods depending on the ee.Type (like `mean()`) and the differences get handled by Julia's multiple dispatch, see [Leveraging Julia's multiple distpatch](#Leveraging-Julia's-multiple-distpatch) section for details.

Another notable difference is how methods are called. For example, if you would like to filter an ImageCollection and then reduce an Image, the syntax changes from `imagecollection.filterDate(start,end).mean()` to `mean(filterDate(imagecollection, start, end))`. This makes the syntax more like native Julia syntax and not object oriented. If you like the Python API of interfacing with EE or want to easily convert your Python code to Julia, then see the [Using the Python API through Julia section](#Using-the-Python-API-through-Julia).

## Importing the package

The official name of this package is `EarthEngine`, this naming convention is used for importing the package to Julia (i.e. `using EarthEngine`). When getting started, users have to run the function `Initialize()` to start an Earth Engine session (this is the same in the Python API). `Initialize()` also dynamically builds the Julia API from the Python API, therefore is can take a few seconds to load. If `Initialize()` is not run before tying any workflow with EarthEngine, you will get an error: `ERROR: ArgumentError: ref of NULL PyObject` because the Python API was not loaded into Julia as in the following example:

**Does not work:** ❌
```julia
using EarthEngine

dem = EE.Image("USGS/SRTMGL1_003")
# ERROR: ArgumentError: ref of NULL PyObject
# Stacktrace:
#     ...
```

**Works:** ✅
```julia
using EarthEngine
# Intialize the API
Initialize()

dem = EE.Image("USGS/SRTMGL1_003")
# returns: EarthEngine.Image(PyObject <ee.image.Image object at ...>)
```

Once imported, the module exports the variable `EE` which allows for users to access the Earth Engine types in Julia with abbreviated syntax. For example, instead of writting `img = EarthEngine.Image()` users can write `img = EE.Image()`. Just for illustration, we can see that the two ways of calling the module are equal:

```julia
EarthEngine.Image === EE.Image
# returns: true
```

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
fc = sample(img;scale=30,numPixels=500)

# works
ndvi(img)
# returns: EarthEngine.Image(PyObject <ee.image.Image object at ...>)

# does not work
ndvi(fc)
#ERROR: MethodError: no method matching ndvi(::EarthEngine.FeatureCollection)
#Closest candidates are:
#  ndvi(::EarthEngine.Image) at REPL[XX]:1
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
    f = EE.Feature(f) # cast type here so we can use EE.map
    r = EE.Number(get(f,"B4"))
    n = EE.Number(get(f,"B5"))
    # apply ndvi-number function
    val = ndvi(n,r)
    return set(f,"ndvi",val)
end

# input a FeatureCollection into ndvi
ndvi_fc = ndvi(fc)
# returns: EarthEngine.FeatureCollection(PyObject <ee.featurecollection.FeatureCollection object at ...>)
```

If you are used to Python then this code should not work (at least not return a FeatureCollection). We clearly defined `ndvi` multiple times and the last definition should not work with a FeatureCollection...so how does it work!? This is the power of multiple dispatch! By providing types Julia is able to determine which function to use depending on the input values.

We can check the different signatures of the function `ndvi` with the following code:

```julia
# check the signatures of `ndvi`
methods(ndvi)
# # 4 methods for generic function "ndvi":
# [1] ndvi(img::EarthEngine.Image) in Main at REPL[XX]:2
# [2] ndvi(fc::EarthEngine.FeatureCollection) in Main at REPL[XX]:2
# [3] ndvi(nir::EarthEngine.Number, red::EarthEngine.Number) in Main at REPL[XX]:2
# [4] ndvi(f) in Main at REPL[XX]:2
```

If you are interested in learning more about mulitple dispatch, then pleae see the following presentation: [The Unreasonable Effectiveness of Multiple Dispatch](https://www.youtube.com/watch?v=kc9HwsxE1OY) by Stefan Karpinski.

## Quirks

### Constructors with multiple dispatch

Due to Juia's multiple dispathcing based on type, sometimes you will have to provide a type as the first argument into a constructor method for an EE object. For example, the function `gt()` has multiple uses: you can compared Images, Arrays, Numbers, etc. but there is also an `EE.Filter` constructor that we can create with `gt()`. If you try to create a filter using the keyword arguments as inputs, such as `gt(;name="B4",value=0.05)`, you will get an error because Julia cannot figure out which method signature to use. To overcome this, one can simply provide a blank object of the desired type as in below:

```julia
filter = gt(EE.Filter(); name="B4", value=0.05)
```

Julia will determine which method signature to use based on which type is provided, i.e. `toList(EE.Reducer())` will return a reducer rather than a list.

When in doubt, you can always provide the EE.Type as the first argument when creating a new object. In reality, it is probably best practice so that the code is more readable by users. Say we want to create a constant image, the two following lines of code are both valid:

```julia
one = constant(1)
one = constant(EE.Image(),1)
```

The method `constant()` is only used to create an image within Earth Engine but providing the type allows for the signature to be defined and it is easy for readers to understand what constant is doing, ultimately making code more maintainable. 


There are more likely than not more quirks in using the EE API this way, these are some that have been found so far. If there is a question or some unexpected behavior please file an [issue on the GitHub repo](https://github.com/KMarkert/EarthEngine.jl/issues)


## Using the Python API through Julia

The `EarthEngine.jl` package also exposes the `ee` Python module so one can use the same code as one would when programming in Python. See the following example of valid Julia and Python code:

```julia
# import the EE package and Initialize an ee session
# this is the only non-Python
using EarthEngine
Initialize()

# now we can access the `ee` module like we would with Python
dem = ee.Image("USGS/SRTMGL1_003");
xy = ee.Geometry.Point(86.9250, 27.9881);
value = dem.sample(xy,scale=30).first().get("elevation")
println(value.getInfo())
# 8729 
```

Accessing the EE API this way is *an exact* match to the Python API so one can simply copy-paste whatever Python code you have using the `ee` module and it will work with this Julia API.
