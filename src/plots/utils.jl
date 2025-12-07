"""
    get_clims(arr)

Get min/max values from input array.

# Arguments
- `arr`: Input array.
"""
get_clims(arr) = (minimum(arr), maximum(arr))

"""
    get_coords(ds)

Get coordinates from netCDF dataset.

# Arguments
- `ds`: NetCDF dataset.

# Returns
- `xh`: x-coordinates.
- `yh`: y-coordinates.
- `TIME`: time-coordinates.
"""
function get_coords(ds)
    xh = ds["x"][:] / 1e3
    yh = ds["y"][:] / 1e3
    TIME = ds["TIME"]
    return xh, yh, TIME
end
