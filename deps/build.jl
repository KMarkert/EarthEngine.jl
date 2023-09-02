using BinDeps
using CondaBinDeps

@BinDeps.setup

# Declare the dependency
ee = library_dependency("earthengine-api")

# Add the conda-forge channel to get the Earth Engine package
CondaBinDeps.Conda.add_channel("conda-forge")

# Get the package itself
provides(CondaBinDeps.Manager, "earthengine-api", ee)
