# EarthEngine.jl Usage

This document serves to illustrate and discuss some of the internals and interesting bits when using the `EarthEngine.jl` Julia API.

The Julia API imports the majority of the functions from the Python API (if there is anything missing please log an [issue](https://github.com/KMarkert/EarthEngine.jl/issues)). The functions lose the `ee.Type` syntax so the one can simply call the methods by name and not have as much code. For example `ee.Reducer.histogram()` is simply `histogram()` in the Julia API. There are multiple versions of some methods depending on the ee.Type (like `mean()`) the differences get handled by Julia's multiple dispatch, see [Leveraging Julia's multiple distpatch](#Leveraging-Julia's-multiple-distpatch) section for details.

Another notable difference is how methods are called. For example, if you would like to filter an ImageCollection and then reduce an Image, the syntax changes from `imagecollection.filterDate(start,end).mean()` to `mean(filterDate(imagecollection, start, end))`. This makes the syntax more like native Julia syntax and not object oriented. If you like the Python API of interfacing with EE or want to easily convert your Python code to Julia, then see the [Using the Python API through Julia section](#Using-the-Python-API-through-Julia).

## Importing the package

The official name of this package is `EarthEngine`, this naming convention is used for importing the package to Julia (i.e. `using EarthEngine`). When getting started, users have to run the function `Initialize()` to start an Earth Engine session (this is the same in the Python API). `Initialize()` also dynamically builds the Julia API from the Python API, therefore is can take a few seconds to load. If `Initialize()` is not run before tying any workflow with EarthEngine, you will get an error: `ERROR: ArgumentError: ref of NULL PyObject` because the Python API was not loaded into Julia as in the following example:

**Does not work:** ❌
```julia
using EarthEngine

dem = EE.Image("USGS/SRTMGL1_003")
# ERROR: UndefVarError: Image not defined
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

Once imported, the module exports the variable `EE` which allows for users to access the Earth Engine types in Julia with abbreviated syntax. For example, instead of writing `img = EarthEngine.Image()` users can write `img = EE.Image()`. Just for illustration, we can see that the two ways of calling the module are equal:

```julia
EarthEngine.Image === EE.Image
# returns: true
```

## EE Types

One nice feature of  Julia is that it supports [types](https://docs.julialang.org/en/v1/manual/types/). This allows for easily creating user defined functions and code that are [type safe](https://en.wikipedia.org/wiki/Type_safety).

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

## Leveraging Julia's multiple dispatch

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

If you are interested in learning more about multiple dispatch, then please see the following presentation: [The Unreasonable Effectiveness of Multiple Dispatch](https://www.youtube.com/watch?v=kc9HwsxE1OY) by Stefan Karpinski.

## Arithmetic with EE Types

Thanks to Julia's multiple dispatch, most mathematical operations on EE Types are supported and are dispatched to the correct method based on type. This makes the syntax for developing algorithms that use math more compact and look more like equations. A quick example of this can be seen when calculate EVI for an image and threshold to determine vegetated areas:

```julia
img = EE.Image("LANDSAT/LT05/C01/T1_SR/LT05_034033_20000913")

# extract bands
b = select(img,"B1")
r = select(img,"B3")
n = select(img,"B4")

# apply evi equation
evi = 2.5 * (n - r) / (n + (6 * r) - (7.5 * b) + 1)
# returns: EarthEngine.Image(PyObject <ee.image.Image object at ...>)

# get evi values over 0.5
veg = evi > 0.5
# returns: EarthEngine.Image(PyObject <ee.image.Image object at ...>)
```

These kind of math operators work on all EE types and will dispatch to the equivalent EE operations if they are available for the types. All [arithmetic operators](https://docs.julialang.org/en/v1/manual/mathematical-operations/#Arithmetic-Operators),most [bitwise operators](https://docs.julialang.org/en/v1/manual/mathematical-operations/#Bitwise-Operators), and all [numeric comparisons](https://docs.julialang.org/en/v1/manual/mathematical-operations/#Numeric-Comparisons) are supported.

It should be noted that if using mathematical operations with EE types, then the results will _always_ be evaluated as Earth Engine server-side operations. Comparisons of values, such as `img1 == img2` is equivalent to `eq(img1,img2)` (i.e. server-side operations) and should not be used for client-side comparisons.

## Quirks

### Constructors with multiple dispatch

Due to Julia's multiple dispatching based on type, sometimes you will have to provide a type as the first argument into a constructor method for an EE object. For example, the function `gt()` has multiple uses: you can compared Images, Arrays, Numbers, etc. but there is also an `EE.Filter` constructor that we can create with `gt()`. If you try to create a filter using the keyword arguments as inputs, such as `gt(;name="B4",value=0.05)`, you will get an error because Julia cannot figure out which method signature to use. To overcome this, one can simply provide a blank object of the desired type as in below:

```julia
filter = gt(EE.Filter(); name="B4", value=0.05)
```

Julia will determine which method signature to use based on which type is provided, i.e. `toList(EE.Reducer())` will return a reducer rather than a list.

When in doubt, you can always provide the EE.Type as the first argument when creating a new object. In reality, it is probably best practice so that the code is explicit on what type is used and more readable by users. Say we want to create a constant image, the two following lines of code are both valid:

```julia
one = constant(1)
one = constant(EE.Image(),1)
```

The method `constant()` is only used to create an image within Earth Engine but in this example providing the type allows for the signature to be defined and it is easy for readers to understand what constant is doing, ultimately making code more maintainable.

### Types within functions when using `map()`

When using the EE Julia API (and relying on multiple dispatch to figure the correct methods to use with data), some type casting is required to define the type of data within functions. This is particularly the case when using mapping functions over EE Collections because information gets passed to multiple sources (i.e. Julia function -> Python -> Earth Engine servers). So, somewhere between all of the translation one needs to be explicit on type information. Take a simple example where a user wants to define a function to calculate NDVI using individual bands:


```julia
# NDVI fucntion
function ndvi(img)
    r = select(img,"B4")
    n = select(img,"B5")

    return (n-r)/(n+r)
end

# get image collection
ic = limit(EE.ImageCollection("LANDSAT/LC08/C01/T1_SR"),100, "CLOUD_COVER")

# apply function over imagery
map(ic, ndvi)
# ERROR: PyError ...
# AttributeError("'Image' object has no attribute 'map'")
```

While this is a perfectly valid code to calculate NDVI from the Earth Engine perspective, this throws an error because within the function using `select()` doesn't know when method signature to use so it will use the first method signature available (which probably isn't the correct one). This ambiguity happens when the function is called via `map()` on the Python side; the inputs are Python Objects and not typed. So, to overcome this ambiguity, we can [provide types to the function arguments](https://docs.julialang.org/en/v1/manual/methods/#Defining-Methods) so that methods within the function know which signature to use. However, this is not enough because the expected type for functions used with map are `PyObject`. To pass the EE types to Python we will use a macro provided by EarthEngine.jl, `@eefunc`, to wrap the typed function which will work on the Python side. The `@eefunc` macro takes a function and the expected EE type to ensure the correct information is passed back and forth between Python and Julia:

```julia
# NDVI fucntion with image casted to EE.Image
function ndvi_typed(img::EE.Image)
    r = select(img,"B4")
    n = select(img,"B5")

    return (n-r)/(n+r)
end

# apply new NDVI function with type casting
# use the @eefunc macro to wrap the type in a Python-friendly function
map(ic, @eefunc ndvi_typed EE.Image)
# returns: EarthEngine.ImageCollection(PyObject <ee.imagefeaturecollection.ImageCollection object at ...>)
```

While this is not required all the time for mapping functions over `EE.ImageCollection` or `EE.FeatureCollection`, it is generally good practice to use `@eefunc` to ensure the types are all correct.

### Using `map()` with `EE.List` types

Within the Python API, the `ee.List` object uses a special approach to manage applying user defined functions using `map()`. The underlying code uses inspection to gather arbitrary arguments and keywords but this inspection only works on functions created in Python (i.e. doesn't work for Julia functions converted to Python). Take a simple example were we would like to square a list of numbers which results in an error:

```julia
# get a list of values
l = sequence(1, 10)

# define a function to square values
foo(x) = multiply(x, x)

map(l, foo)
# ERROR: PyError ....
# TypeError('unsupported callable')
```

Again, this is perfectly valid code, but what this means is that the EE Python API cannot understand how to use the function from the Julia side and is throwing an error. The `@eefunc` macro is used to overcome this error is provided to extract out a Python callable object from functions defined in Julia. If no type is provided to `@eefunc` it will simply wrap the Julia function on the Python side with no types. Therefore, users will only need to add in minimal code to make the function applicable as in the following example:

```julia
map(l, @eefunc foo)
# returns: EarthEngine.List(PyObject <ee.ee_list.List object at object at ...>)
```

However, in more complex functions that [require typing](#Types-within-functions-when-using-map()), the mapped function will need to take `EE.ComputedObject` types (this is the [default type for all `ee.List.map` functions](https://developers.google.com/earth-engine/apidocs/ee-list-map)). For example, if we would like to extract date information from an ImageCollection and format the dates to a string we would need to first cast the variable to `EE.Date` in the function then apply `format()` (this is because `format()` has a signature for both `EE.Number` and `EE.Date`). On the server side Earth Engine lists only take ComputedObjects as the input argument and then we have to cast to the preffered type within the function or else we will get an error. perform whichever operations we would like within the function:

```julia
# define function to convert ee date object to string
function bar(d)
   d = EE.Date(d)
   return format(d,"YYYY-MM-dd")
end

# define the function which takes EE.ComputedObject
function bar_typed(d::EE.ComputedObject)
    d = EE.Date(d)
    return format(d,"YYYY-MM-dd")
 end

# get a list of EE Dates
ic = limit(EE.ImageCollection("LANDSAT/LC08/C01/T1_SR"), 10)
dates = aggregate_array(ic, "system:time_start")

# apply basic function...will get an error
map(dates, @eefunc bar)
# ERROR: (in a Julia function called from Python)
# JULIA: KeyError: key "format" not found

# apply function typed with EE.ComputedObject
map(dates, @eefunc bar EE.ComputedObject)
# returns: EarthEngine.List(PyObject <ee.ee_list.List object at ...>)
```

In short, if using `map()` with `EE.List` types you will need to use `@eefunc` macro to wrap the function and the only support type as input into functions for `EE.List` is `EE.ComputedObject`. If this is all too much, one can simply avoid using Lists altogether and do all of the processing with `EE.Colletion` types (in fact it is recommended to [avoid converting Earth Engine data to lists](https://developers.google.com/earth-engine/guides/best_practices#avoid-converting-to-list-unnecessarily)).

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
