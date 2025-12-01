using GLMakie
using NCDatasets

include("utils.jl")

function build_heatmap_axis(fig)
    ax = Axis(
        fig[1, 2],
        xlabel = "x (km)",
        ylabel = "y (km)",
        aspect = DataAspect(),
        # title = "$varname at time = $(round(TIME[1], digits = 2))",
        xautolimitmargin = (0, 0),  # Prevent adding margin to xlimits
    )
    return ax
end

function plot_heatmap(fig, ax, xh, yh, da, TIME)
    data0 = da[:, :, 1] # Initial slice
    clims = get_clims(data0)

    heatmap = heatmap!(
        ax,
        xh,
        yh,
        data0,
        colormap = :viridis,
        colorrange = clims,
        interpolate = false,
    )

    # Line plot across a selected y-index (initially first y)
    # y_line = [yh[1] for i in 1:length(xh)]
    y_line = fill(yh[1], length(xh))
    heatmap_line_plot = lines!(ax, xh, y_line; color = :red, linewidth = 2)

    # Round float tick values to int (stops axes moving around)
    int_tick(x) = string.(round.(Int, x))
    Colorbar(fig[1, 3], heatmap; tickformat = int_tick)
    return heatmap, heatmap_line_plot
end

function build_line_axis(fig)
    ax = Axis(
        fig[2, 2],
        xlabel = "x (km)",
        # ylabel = "$varname",
        # title = "Cross-section at y = $(round(yh[1], digits = 2)) km",
        xautolimitmargin = (0, 0),  # Prevent adding margin to xlimits
    )
    return ax
end

function plot_line(fig, ax, xh, da, TIME)
    line = lines!(
        ax,
        xh,
        da[:, 1, 1],    # Initial slice at yidx=1, t=1
        color = :blue,
        linewidth = 2,
    )
    return line
end

function build_interface(fig, yh, nt, varnames)
    y_slider = Slider(fig[1, 1], range = 1:length(yh), startvalue = 1, horizontal = false)
    ax = build_heatmap_axis(fig)
    ax2 = build_line_axis(fig)
    linkxaxes!(ax, ax2) # Link x-axes so they line up

    # Add menu for variable selection
    # Ref: https://docs.makie.org/dev/reference/blocks/menu
    menu_layout = GridLayout(tellwidths = true)
    fig[3, 2] = menu_layout # Using this to match the layout of the slider grid
    Label(menu_layout[1, 1], "Variable", tellwidth = true)
    varname_menu = Menu(menu_layout[1, 2], options = varnames, default = varnames[1])

    slider_grid = SliderGrid(
        fig[4, 2],
        (label = "Timestep", range = 1:nt, format = "{:.1d}", startvalue = 1),
        tellheight = true,
    )
    time_slider = slider_grid.sliders[1]

    return y_slider, ax, ax2, varname_menu, time_slider
end

function plot_mismip_plus(files, output, format, dpi)
    ds = Dataset(files[1])

    # Filter out variables that are not 3D
    varnames = filter(x -> ndims(ds[x]) == 3, keys(ds))

    xh, yh, TIME = get_coords(ds)

    nt = length(TIME)

    fig = build_figure()
    y_slider, ax, ax2, varname_menu, time_slider = build_interface(fig, yh, nt, varnames)

    # Initialise plots
    varname = varnames[1]
    da = ds[varname]

    heatmap, heatmap_line_plot = plot_heatmap(fig, ax, xh, yh, da, TIME)
    line = plot_line(fig, ax2, xh, da, TIME)

    # Menu callbacks

    ## Selecting variable
    on(varname_menu.selection) do varname
        t = time_slider.value[]
        da = ds[varname]

        ax.title = "$varname at time = $(round(TIME[t], digits = 2))"
        ax2.ylabel = "$varname"

        # Update heatmap
        heatmap[3][] = da[:, :, t]
        heatmap.colorrange[] = get_clims(da[:, :, t])

        # Update bottom slice to reflect new time selection
        yidx = y_slider.value[]
        line[1][] = Point2f.(xh, @view da[:, yidx, t])

        ax2.title = "Cross-section at y = $(round(yh[yidx], digits = 2)) km"
        autolimits!(ax2)
    end

    # Slider callbacks

    ## y slider callback
    on(y_slider.value) do yidx
        varname = varname_menu.selection[]
        da = ds[varname]

        # Update red horizontal line on heatmap
        y_line = fill(yh[yidx], length(xh))
        heatmap_line_plot[1][] = Point2f.(xh, y_line)
        ax2.ylabel = "$varname"

        # Update bottom plot (slice across x at this y, current time t)
        t = time_slider.value[]
        line[1][] = Point2f.(xh, @view da[:, yidx, t])

        # Update title of bottom plot
        ax2.title = "Cross-section at y = $(round(yh[yidx], digits = 2)) km"

        autolimits!(ax2)
    end

    ## Time slider callback
    on(time_slider.value) do t
        varname = varname_menu.selection[]
        da = ds[varname]
        da_slice = @view da[:, :, t]

        # Update heatmap
        heatmap[3][] = da_slice
        heatmap.colorrange[] = get_clims(da_slice)
        ax.title = "$varname at time = $(round(TIME[t], digits = 2))"
        ax2.ylabel = "$varname"

        # Update bottom slice to reflect new time selection
        yidx = y_slider.value[]
        line[1][] = Point2f.(xh, @view da[:, yidx, t])

        autolimits!(ax2)
    end

    if isnothing(output)
        display(fig)
    else
        save(output, fig)
        println("Plot saved to: $output")
    end
end

