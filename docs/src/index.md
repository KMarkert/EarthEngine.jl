# EE.jl
Google Earth Engine in Julia!

`EE.jl` is used to interface with the *amazing* cloud-based geospatial processing platform, [Google Earth Engine](https://earthengine.google.com), using the Julia programming language. This 

You can use `EE.jl` in the following two ways.

1. Interface with the good ole' object-oriented Python API that everyone knows and loves through Julia (i.e. `imagecollection.mean()`)
2. Interface with EarthEngine using a functional programming Julia-like syntax that leverages Types and multiple dispacthing.

See the `Usage` section for more in depth discussion between the two.

## Why Julia + EE?

The officially supported Earth Engine are written in [JavaScript](https://developers.google.com/earth-engine/guides/getstarted) and [Python](https://developers.google.com/earth-engine/guides/python_install) API. These APIs provide great interfaces to the platform but limits some developers to those languages. Other community developed APIs have been developed ,like [rgee](https://github.com/r-spatial/rgee/) and allow developers to interface with EE in their favorite languages.

Julia is a modern programming language that has the feel of a scripting language with the performance compiled languages (thanks to its JIT compilation). Julia is full of features with a couple of particular interest such as types and multiple dispatch that this package leverages to make developing EE workflows more expressive.

## Installation

To use EarthEngine with Julia, we will use the existing Python API and call the functions through Julia. This is done through Julia’s [PyCall package](https://github.com/JuliaPy/PyCall.jl) but we will need to install the EE API for use within the Julia environment. To do this using the following instructions:

```julia
$ julia
julia> ]
pkg> add PyCall Conda
julia> using Conda
julia> Conda.add("earthengine-api",channel="conda-forge");
```

Now we can install the EE package.

```julia
$ julia
julia> ]
pkg> add EE
julia> using EE
```

If everything went well then you should have been able to import the EE package without any errors.

## Quick start

To get started illustrating how to execute EE workflows using Julia, some of the [examples using the Python API](https://colab.research.google.com/github/google/earthengine-api/blob/master/python/examples/ipynb/ee-api-colab-setup.ipynb) are replicated using the Julia API.

### Test the API

The first example is focused on importing the packing and performing a small geospatial process. Here the SRTM elevation data is imported and queried at the geospatial coordinates of Mount Everest to get the elevation value.

```julia
using EE
Initialize()
dem = EE.Image("USGS/SRTMGL1_003");
xy = Point(86.9250, 27.9881);
value = get(first(sample(dem,xy,30)),"elevation")
println(getInfo(value))
# should print: 8729
```

### Plotting data from EE

As a more extensive example, we will sample data from a raster dataset. This is a common workflow for geospatial sciences whether looking at relationships between variables or sampling data for ML workflows. Here we load in Landsat image, sample band values, and plot the relationship of the bands.

```julia
using Plots
using EE
Initialize()
img = EE.Image("LANDSAT/LT05/C01/T1_SR/LT05_034033_20000913");
band_names = ["B3","B4"]
samples_fc = sample(divide(select(img,band_names),10000);scale=30,numPixels=500)
reducer = repeat(EE.Reducer(ee.Reducer.toList()),length(band_names))
sample_cols =  EE.Dictionary(reduceColumns(samples_fc, reducer, band_names))
sample_data = getInfo(get(sample_cols,"list"))

# plot the results
theme(:bright)
scatter(sample_data[1,:],sample_data[2,:],markersize=4,alpha=0.8,xlabel="Red",ylabel="NIR",leg=false)
```




