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

Thanks to Julia's multiple dispatch, most mathematical operations on EE Types are supported and are dispatched to the correct method based on type. A quick example of this can be seen when calculate EVI for an image:

```julia
img = EE.Image("LANDSAT/LT05/C01/T1_SR/LT05_034033_20000913")

# extract bands
b = select(img,"B1")
r = select(img,"B3")
n = select(img,"B4")
# define equation coefficients
c1 = EE.Image(2.5)
c2 = EE.Image(6)
c3 = EE.Image(7.5)
c4 = EE.Image(1)

# apply evi equation
evi = c1 * (n - r) / (n + (c2 * r) - (c3 * b) + c4)
```

It should be noted that when using mathematical arithmetic with EE types, all variables in the equation are required to be an EE type otherwise an error will occur (hence why the coefficients are defined as images above). All [arithmetic operators](https://docs.julialang.org/en/v1/manual/mathematical-operations/#Arithmetic-Operators) and most [bitwise operators](https://docs.julialang.org/en/v1/manual/mathematical-operations/#Bitwise-Operators) are supported.

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

    return divide(subtract(n,r),add(n,r))
end

# get image collection
ic = limit(EE.ImageCollection("LANDSAT/LC08/C01/T1_SR"),100)

# apply function over imagery
map(ic, ndvi)
# ERROR: PyError ...
# AttributeError("'Image' object has no attribute 'map'")
```

While this is a perfectly valid code to calculate NDVI from the Earth Engine perspective, this throws an error because within the function using `select()` doesn't know when method signature to use so it will use the first one on the list (which probably isn't correct). This ambiguity happens when the function is called via `map()` on the Python side; the inputs are Python Objects and not typed. So, to overcome this ambiguity, one can simply specify the type of the argument initially to ensure the correct information is passed back and forth:

```julia
# NDVI fucntion with image casted to EE.Image
function ndvi_typed(img)
    img = EE.Image(img)
    r = select(img,"B4")
    n = select(img,"B5")

    return (divide(subtract(n,r),add(n,r)))
end

# apply new NDVI function with type casting
map(ic, ndvi_typed)
# returns: EarthEngine.ImageCollection(PyObject <ee.imagefeaturecollection.ImageCollection object at ...>)
```

Earlier it was mentioned that the type can be specified for the input arguments of functions. While this is true for the Julia side of things, `map()` is called on the Python side which does not have a typing system. The inputs to all mapped functions will be `PyObject` leading to need for users to cast the types within the functions.

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

Again, this is perfectly valid code, but what this means is that the EE Python API cannot understand how to use the function from the Julia side and is throwing an error. To overcome this limitation, a macro `@eefunc` is provided to extract out a Python callable object from functions defined in Julia. Therefore, users will only need to add in minimal code to make the function applicable as in the following example:

```julia
map(l, @eefunc foo)
# returns: EarthEngine.List(PyObject <ee.ee_list.List object at object at ...>)
```

However, in more complex functions that [require typing](#Types-within-functions-when-using-map()), there is an known issue where the Julia typing causes friction with how Earth Engine Lists handle functions on the Python side. For example, if we would like to extract date information from an ImageCollection and format the dates to a string we would need to first cast the variable to EE.Date then apply `format()` (this is because `format()` has a signature for both `EE.Number` and `EE.Date`) but this leads to another error:

```julia
# this function uses the EE Python API
function bar(date)
    date = EE.Date(date)
    return format(date, "YYYY-MM-dd")
end

ic = limit(EE.ImageCollection("LANDSAT/LC08/C01/T1_SR"), 10)
dates = aggregate_array(ic, "system:time_start")

map(dates, @eefunc bar)
# ERROR: (in a Julia function called from Python)
# JULIA: KeyError: key "format" not found
```

To overcome this problem, one would need to either 1) write the function using the [EE Python API through Julia](#Using-the-Python-API-through-Julia) and apply it normally with `map()` or 2) simply avoid using Lists altogether (in fact it is recommended to [avoid converting Earth Engine data to lists](https://developers.google.com/earth-engine/guides/best_practices#avoid-converting-to-list-unnecessarily)).

In summary, to map a function over an Earth Engine List one would need to supply the `@eefunc` macro in front of the function to convert it into a Python function. Furthermore, if complex processing is required on lists, it is recommended to try avoiding lists or use the EE Python API through Julia.


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
