# EE.jl

Google Earth Engine in Julia

## Installation

Coming soon...

## Usage Example

```
$ julia
julia> using EE
julia> Initialize()
julia> dem = EE.Image("USGS/SRTMGL1_003")
julia> xy = Point(86.9250, 27.9881)
julia> value = get(first(sample(dem,xy,30)),"elevation")
julia> getInfo(value)
# should print 8729
```

## 🚨 Warning 🚨

This package is in development and should not be used for production services! This package is more of a proof of concept in using the EarthEngine API with type definitions. There is some unexpected behavior with the internal typing from the EarthEngine API.

There are most likely function definitions that colober with the Julia Base definitions so if you come across any issues, please log an [issue of Github](https://github.com/KMarkert/EE.jl/issues) so that it can be resolved.
