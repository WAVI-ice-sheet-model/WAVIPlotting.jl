
function build_figure()
    fig = Figure(size = (1500, 700), layout = GridLayout(tellwidths = true))
    return fig
end

get_clims(arr) = (minimum(arr), maximum(arr))

function get_coords(ds)
    xh = ds["x"][:] / 1e3
    yh = ds["y"][:] / 1e3
    TIME = ds["TIME"]
    return xh, yh, TIME
end
