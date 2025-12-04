"""
    get_clims(arr)

Get data range for given array.
"""
get_clims(arr) = (minimum(arr), maximum(arr))

"""
    get_coords(ds)

Get coordinates from netCDF dataset.
"""
function get_coords(ds)
    xh = ds["x"][:] / 1e3
    yh = ds["y"][:] / 1e3
    TIME = ds["TIME"]
    return xh, yh, TIME
end
