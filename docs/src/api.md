# EE.jl API

The `EE.jl` API dynamically wraps the EarthEngine Python API, so it defines the types and methods on-the-fly when initializing a session. This means there are few actual Julia functions defined mostly meant to create Julia methods and types from the Python API (see below). 

For more in depth documentation on specific methods for using the EarthEngine API, see the official [Earth Engine Documention](https://developers.google.com/earth-engine/apidocs).

```@docs
Initialize()
```

```@docs
Authenticate()
```

```@docs
EarthEngine.ee_wrap
```

```@docs
EarthEngine.pyattr
```

```@docs
EarthEngine.@pytype
```

```@docs
EarthEngine.pyattr_set
```

```@docs
EarthEngine.@pyattr 
```