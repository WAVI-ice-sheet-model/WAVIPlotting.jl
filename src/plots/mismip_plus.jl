using GLMakie
using NCDatasets

include("utils.jl")

function build_heatmap_axis(fig; row = 1)
    println("Row:", row)
    ax = Axis(
        fig[row, 2],
        xlabel = "x (km)",
        ylabel = "y (km)",
        #aspect = DataAspect(),
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

    ## Round float tick values to int (stops axes moving around)
    #int_tick(x) = string.(round.(Int, x))
    #Colorbar(fig[1, 3], heatmap; tickformat = int_tick)
    return heatmap
end

function plot_heatmap_cross_section_line(fig, ax, xh, yh, da, TIME)
    # Line plot across a selected y-index (initially first y)
    # y_line = [yh[1] for i in 1:length(xh)]
    y_line = fill(yh[1], length(xh))
    heatmap_line_plot = lines!(ax, xh, y_line; color = :red, linewidth = 2)
    return heatmap_line_plot
end

function build_line_axis(fig; row = 2)
    ax = Axis(
        fig[row, 2],
        xlabel = "x (km)",
        # ylabel = "$varname",
        # title = "Cross-section at y = $(round(yh[1], digits = 2)) km",
        xautolimitmargin = (0, 0),  # Prevent adding margin to xlimits
    )
    # Reserve space so plot doesn't jump around as y-value tick label size increases
    ax.yticklabelspace = 50.0
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

function build_interface(fig, yh, nt, varnames; n_heatmaps = 1)
    y_slider = Slider(fig[1, 1], range = 1:length(yh), startvalue = 1, horizontal = false)
    axes = []
    # Build a heatmap axis per netCDF file
    for i in 1:n_heatmaps
        push!(axes, build_heatmap_axis(fig; row = i))
    end
    # Set last axis to be the cross-sectional line plot
    push!(axes, build_line_axis(fig, row = n_heatmaps + 1))

    # Link all x-axes so they line up
    # Force all axes to share the same xlims based on the first heatmap
    linkxaxes!(axes...)

    # if n_heatmaps = 2
    #row_heatmap_starting = 1
    #row_line_plot = 3
    #row_menu = row_line_plot + 1
    #row_slider_grid = row_line_plot + 2

    # Add menu for variable selection
    # Ref: https://docs.makie.org/dev/reference/blocks/menu
    menu_layout = GridLayout(tellwidths = true)
    fig[n_heatmaps + 2, 2] = menu_layout # Using this to match the layout of the slider grid
    Label(menu_layout[1, 1], "Variable", tellwidth = true)
    varname_menu = Menu(menu_layout[1, 2], options = varnames, default = varnames[1])

    slider_grid = SliderGrid(
        fig[n_heatmaps + 3, 2],
        (label = "Timestep", range = 1:nt, format = "{:.1d}", startvalue = 1),
        tellheight = true,
    )
    time_slider = slider_grid.sliders[1]

    return y_slider, axes, varname_menu, time_slider
end

function update_plot(axes, files, heatmaps_vector, varname, xh, yh, TIME; t, yidx)
    empty!(axes[end])
    for (i, file) in enumerate(files)
        axes[i].title = "$varname at time = $(round(TIME[t], digits = 2))"
        ds = Dataset(files[i])
        da = ds[varname]
        # Update heatmap
        heatmaps_vector[i][3][] = @view da[:, :, t]
        heatmaps_vector[i].colorrange[] = get_clims(@view da[:, :, t])

        # Update bottom line axis to reflect new time selection
        line = lines!(
            axes[end],
            xh,
            da[:, yidx, t],
            label = files[i],
            #color = :red,
            linewidth = 2,
        )
    end

    axes[end].ylabel = "$varname"

    #line[1][] = Point2f.(xh, @view da[:, yidx, t])

    axes[end].title = "Cross-section at y = $(round(yh[yidx], digits = 2)) km"
end

function plot_mismip_plus(files, output, format, dpi)
    ds = Dataset(files[1])

    fig_width = 1500
    fig_height = 350 * length(files)

    # Filter out variables that are not 3D
    varnames = filter(x -> ndims(ds[x]) == 3, keys(ds))

    xh, yh, TIME = get_coords(ds)

    nt = length(TIME)

    fig = build_figure(;size = (fig_width, fig_height))
    y_slider, axes, varname_menu, time_slider = build_interface(fig, yh, nt, varnames; n_heatmaps = length(files))

    # Initialise plots
    varname = varnames[1]
    da = ds[varname]

    heatmaps_vector = []

    for (i, file) in enumerate(files)
	heatmap = plot_heatmap(fig, axes[i], xh, yh, da, TIME)
	push!(heatmaps_vector, heatmap)
    end

    heatmap_line_plot = plot_heatmap_cross_section_line(fig, axes[1], xh, yh, da, TIME)
    line = plot_line(fig, axes[end], xh, da, TIME)

    update_plot(axes, files, heatmaps_vector, varname, xh, yh, TIME, t = 1, yidx = 1)
    leg = axislegend(axes[end], position = :rt, framevisible = true, framecolor = :transparent, backgroundcolor = :transparent)

    # Menu callbacks
    ## Selecting variable
    on(varname_menu.selection) do varname
        t = time_slider.value[]
        yidx = y_slider.value[]

	update_plot(axes, files, heatmaps_vector, varname, xh, yh, TIME; t, yidx)
    end

    # Slider callbacks
    ## y slider callback
    on(y_slider.value) do yidx
        varname = varname_menu.selection[]
        t = time_slider.value[]

        # Update red horizontal line on heatmap
        y_line = fill(yh[yidx], length(xh))
        heatmap_line_plot[1][] = Point2f.(xh, y_line)

	update_plot(axes, files, heatmaps_vector, varname, xh, yh, TIME; t, yidx)
    end
    ## time slider callback
    on(time_slider.value) do t
        varname = varname_menu.selection[]
        yidx = y_slider.value[]

	update_plot(axes, files, heatmaps_vector, varname, xh, yh, TIME; t, yidx)
    end

    if isnothing(output)
        display(fig)
    else
        save(output, fig)
        println("Plot saved to: $output")
    end
end

