
"""
    build_figure(; size = (1500, 700))

Build and return figure object with a grid layout for heatmaps and line plot.
"""
function build_figure(; size = (1500, 700))
    fig = Figure(size = size, layout = GridLayout(tellwidths = true))
    return fig
end

"""
    build_heatmap_axis(fig; row = 1)

Build and return heatmap axis object.
"""
function build_heatmap_axis(fig; row = 1)
    @info "Row: $row"
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

"""
    build_interface(fig, yh, TIME, varnames; n_heatmaps = 1)

Build Makie interface for heatmaps and line plot.
"""
function build_interface(fig, yh, TIME, varnames; n_heatmaps = 1)
    slider_line_width = 15

    # Slider for selecting heatmap cross-section slice
    slider_layout = GridLayout(fig[1, 1])
    Label(slider_layout[1, 1], "Cross-section slice", tellwidth = true, rotation = pi/2)
    y_slider = Slider(
        slider_layout[1, 2],
        range = 1:length(yh),
        startvalue = 1,
        horizontal = false,
        linewidth = slider_line_width,
    )
    axes = []
    # Build a heatmap axis per netCDF file
    for i = 1:n_heatmaps
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
    fig[n_heatmaps+2, 2] = menu_layout # Using this to match the layout of the slider grid
    Label(menu_layout[1, 1], "Variable", tellwidth = true)
    varname_menu = Menu(menu_layout[1, 2], options = varnames, default = varnames[1])

    slider_grid = SliderGrid(
        fig[n_heatmaps+3, 2],
        (
            label = "Timestep",
            range = 1:length(TIME),
            format = i -> string(round(TIME[i], digits = 0)),
            startvalue = 1,
            linewidth = slider_line_width,
        ),
        tellheight = true,
    )

    time_slider = slider_grid.sliders[1]

    # Create a sub-layout for the slider and toggle
    slider_layout = GridLayout(fig[n_heatmaps+4, 2])

    Label(slider_layout[1, 1], "Colourbar", tellwidth = true)
    min_label = Label(slider_layout[1, 2], tellwidth = true)
    colorbar_slider = IntervalSlider(slider_layout[1, 3], linewidth = slider_line_width)
    max_label = Label(slider_layout[1, 4], tellwidth = true)

    # Add toggle to lock the range
    lock_toggle = Toggle(slider_layout[1, 5], active = false)
    Label(slider_layout[1, 6], "Lock over timesteps")

    return y_slider,
    axes,
    varname_menu,
    time_slider,
    colorbar_slider,
    lock_toggle,
    min_label,
    max_label
end

"""
    plot_heatmap(fig, ax, xh, yh, da, varname, TIME)

Plot heatmap for initial slice of variable.
"""
function plot_heatmap(fig, ax, xh, yh, da, varname, TIME)
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

    return heatmap
end

"""
    plot_heatmap_cross_section_line(fig, ax, xh, yh, da, TIME)

Plot cross-section line over first heatmap.
"""
function plot_heatmap_cross_section_line(fig, ax, xh, yh, da, TIME)
    # Line plot across a selected y-index (initially first y)
    # y_line = [yh[1] for i in 1:length(xh)]
    y_line = fill(yh[1], length(xh))
    heatmap_line_plot = lines!(ax, xh, y_line; color = :red, linewidth = 2)
    return heatmap_line_plot
end

"""
    build_line_axis(fig; row = 2)

Build line plot axis.
"""
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

"""
    plot_line(fig, ax, xh, da, TIME)

Plot line plot for initial cross-section and timestep.
"""
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