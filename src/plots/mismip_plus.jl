using GLMakie
using NCDatasets

include("utils.jl")
include("ui.jl")

function get_arr_range(files, varname, t)
    minval, maxval = floatmax(Float32), floatmin(Float32)
    for (i, file) in enumerate(files)
        ds = Dataset(files[i])
        da = ds[varname]

        minval = min(minval, minimum(@view da[:, :, t]))
        maxval = max(maxval, maximum(@view da[:, :, t]))
    end
    return minval, maxval
end

function get_global_limits(files, varname)
    minval, maxval = floatmax(Float32), floatmin(Float32)
    for file in files
        ds = Dataset(file)
        da = ds[varname]
        # Compute global min/max for this variable across all time
        minval = min(minval, minimum(da))
        maxval = max(maxval, maximum(da))
    end
    return minval, maxval
end

function update_plot(
    axes,
    files,
    heatmaps_vector,
    heatmap_cbar,
    colorbar_slider,
    varname,
    xh,
    yh,
    TIME,
    figure_title;
    t,
    yidx,
    update_limits = true,
)
    empty!(axes[end])
    figure_title.text = "$varname at timestep = $(round(TIME[t], digits = 2))"
    for (i, file) in enumerate(files)
        axes[i].title = "File: $file"
        ds = Dataset(files[i])
        da = ds[varname]
        # Update heatmap
        heatmaps_vector[i][3][] = @view da[:, :, t]

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

    # Get data range for current timestep
    curr_min, curr_max = get_arr_range(files, varname, t)

    axes[end].ylabel = "$varname"
    heatmap_cbar.label = "$varname"

    axes[end].title = "Cross-section at y = $(round(yh[yidx], digits = 2)) km"

    if update_limits
        # Unlocked: Update slider interval to match current data range
        update_colorbar_slider_interval(colorbar_slider, curr_min, curr_max)
        cmin, cmax = curr_min, curr_max
    else
        # Locked: Use existing slider interval across timesteps
        cmin, cmax = colorbar_slider.interval[]
    end

    # Note: We rely on the slider callback to update the colorbar and labels
    # update_colorbar(files, heatmaps_vector, cmin, cmax)

    return cmin, cmax
end

function update_colorbar(files, heatmaps_vector, minval, maxval)
    for (i, file) in enumerate(files)
        heatmaps_vector[i].colorrange[] = (minval, maxval)
    end
end

function update_colorbar_slider_range(colorbar_slider, minval, maxval)
    @debug "Updating colorbar slider range to $(minval) to $(maxval)"
    colorbar_slider.range[] = LinRange(minval, maxval, 1000)
end

function update_colorbar_slider_interval(colorbar_slider, minval, maxval)
    @debug "Updating colorbar slider interval to $(minval) to $(maxval)"
    set_close_to!(colorbar_slider, minval, maxval)
end

function plot_mismip_plus(files, output, format, dpi)
    ds = Dataset(files[1])

    fig_width = 1500
    fig_height = 350 * length(files)

    # Filter out variables that are not 3D
    varnames = filter(x -> ndims(ds[x]) == 3, keys(ds))

    xh, yh, TIME = get_coords(ds)

    nt = length(TIME)

    fig = build_figure(; size = (fig_width, fig_height))
    y_slider,
    axes,
    varname_menu,
    time_slider,
    colorbar_slider,
    lock_toggle,
    min_label,
    max_label = build_interface(fig, yh, TIME, varnames; n_heatmaps = length(files))

    # Initialise plots
    varname = varnames[1]
    da = ds[varname]

    heatmaps_vector = []

    for (i, file) in enumerate(files)
        heatmap = plot_heatmap(fig, axes[i], xh, yh, da, varname, TIME)
        push!(heatmaps_vector, heatmap)
    end

    # Add Colourbar
    ## Round float tick values to int (stops axes moving around)
    int_tick(x) = string.(round.(Int, x))
    heatmap_cbar =
        Colorbar(fig[1:end, 3], heatmaps_vector[1]; tickformat = int_tick, label = varname)

    heatmap_line_plot = plot_heatmap_cross_section_line(fig, axes[1], xh, yh, da, TIME)
    line = plot_line(fig, axes[end], xh, da, TIME)

    figure_title = Label(
        fig[0, :],
        "$varname at time = $(round(TIME[time_slider.value[]], digits=2))",
        fontsize = 30,
    )

    # Initialise slider range with global limits
    global_min, global_max = get_global_limits(files, varname)
    update_colorbar_slider_range(colorbar_slider, global_min, global_max)

    ## Colourbar range setting callback
    on(colorbar_slider.interval) do t
        min_label.text = string(round(t[1], digits = 2))
        max_label.text = string(round(t[2], digits = 2))
        update_colorbar(files, heatmaps_vector, t[1], t[2])
    end

    update_plot(
        axes,
        files,
        heatmaps_vector,
        heatmap_cbar,
        colorbar_slider,
        varname,
        xh,
        yh,
        TIME,
        figure_title;
        t = 1,
        yidx = 1,
        update_limits = true,
    )
    leg = axislegend(
        axes[end],
        position = :rt,
        framevisible = true,
        framecolor = :transparent,
        backgroundcolor = :transparent,
    )

    # Menu callbacks
    ## Selecting variable
    on(varname_menu.selection) do varname
        t = time_slider.value[]
        yidx = y_slider.value[]

        # Update slider range to new variable's global limits
        global_min, global_max = get_global_limits(files, varname)
        update_colorbar_slider_range(colorbar_slider, global_min, global_max)

        update_plot(
            axes,
            files,
            heatmaps_vector,
            heatmap_cbar,
            colorbar_slider,
            varname,
            xh,
            yh,
            TIME,
            figure_title;
            t,
            yidx,
            update_limits = true,
        )
        #minval, maxval = get_arr_range(files, varname, t)
        #println(minval, "\t", maxval)
    end

    # Slider callbacks
    ## y slider callback
    on(y_slider.value) do yidx
        varname = varname_menu.selection[]
        t = time_slider.value[]

        # Update red horizontal line on heatmap
        y_line = fill(yh[yidx], length(xh))
        heatmap_line_plot[1][] = Point2f.(xh, y_line)

        update_plot(
            axes,
            files,
            heatmaps_vector,
            heatmap_cbar,
            colorbar_slider,
            varname,
            xh,
            yh,
            TIME,
            figure_title;
            t,
            yidx,
            update_limits = false,
        )
    end
    ## time slider callback
    on(time_slider.value) do t
        varname = varname_menu.selection[]
        yidx = y_slider.value[]

        update_plot(
            axes,
            files,
            heatmaps_vector,
            heatmap_cbar,
            colorbar_slider,
            varname,
            xh,
            yh,
            TIME,
            figure_title;
            t,
            yidx,
            update_limits = !lock_toggle.active[],
        )
    end
    if isnothing(output)
        display(fig)
    else
        save(output, fig)
        @info "Plot saved to: $output"
    end
end
