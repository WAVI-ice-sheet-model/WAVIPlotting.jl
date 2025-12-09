using GLMakie
using NCDatasets

include("utils.jl")
include("ui.jl")

"""
    get_arr_range(datasets, varname, t)

Get data range for current timestep across all netCDF files.

# Arguments
- `datasets`: List of NetCDF datasets.
- `varname`: Variable name to get range for.
- `t`: Timestep index.

# Returns
- `minval`: Minimum value.
- `maxval`: Maximum value.
"""
function get_arr_range(datasets, varname, t)
    minval, maxval = floatmax(Float32), floatmin(Float32)
    for ds in datasets
        slice = ds[varname][:, :, t]
        minval = min(minval, minimum(slice))
        maxval = max(maxval, maximum(slice))
    end
    return minval, maxval
end

"""
    get_global_limits(datasets, varname)

Get global data range for given variable across all netCDF files.

# Arguments
- `datasets`: List of NetCDF datasets.
- `varname`: Variable name.

# Returns
- `minval`: Minimum value.
- `maxval`: Maximum value.
"""
function get_global_limits(datasets, varname)
    minval, maxval = floatmax(Float32), floatmin(Float32)
    for ds in datasets
        v = ds[varname]
        minval = min(minval, minimum(v))
        maxval = max(maxval, maximum(v))
    end
    return minval, maxval
end

"""
    update_plot(axes::Vector{Axis}, datasets, heatmaps_vector::Vector{Heatmap}, line_observables::Vector{Observable}, heatmap_cbar::Colorbar, colorbar_slider::Slider, varname::String, xh::Vector{Float64}, yh::Vector{Float64}, TIME::Vector{Float64}, figure_title::Label; t::Int, yidx::Int, update_limits::Bool = true)

Update plot for given variable, timestep and y-index.

# Arguments
- `axes`: List of axes objects.
- `datasets`: List of NetCDF datasets.
- `heatmaps_vector`: List of heatmap objects.
- `line_observables`: List of line observables.
- `heatmap_cbar`: Heatmap colorbar object.
- `colorbar_slider`: Colorbar slider object.
- `varname`: Variable name.
- `xh`: x-coordinates.
- `yh`: y-coordinates.
- `TIME`: Time-coordinates.
- `figure_title`: Figure title.

# Keywords
- `t`: Timestep.
- `yidx`: y-index.
- `update_limits=true`: Whether to update limits.
"""
function update_plot(
    axes::Vector{Axis},
    datasets,
    heatmaps_vector::Vector{Heatmap},
    line_observables::Vector{Observable},
    heatmap_cbar::Colorbar,
    colorbar_slider::IntervalSlider,
    varname::String,
    xh::Vector{Float64},
    yh::Vector{Float64},
    TIME::Vector{Float64},
    figure_title::Label;
    t::Int,
    yidx::Int,
    update_limits::Bool = true,
)
    figure_title.text = "$varname at timestep = $(round(TIME[t], digits = 2))"
    curr_min, curr_max = floatmax(Float32), floatmin(Float32)
    for (i, ds) in enumerate(datasets)
        # Read only the slice
        slice = ds[varname][:, :, t]

        # Update heatmap
        heatmaps_vector[i][3][] = slice

        # Update bottom line axis
        # Update the observable for the line
        line_observables[i][] = ds[varname][:, yidx, t]

        # Update min/max
        curr_min = min(curr_min, minimum(slice))
        curr_max = max(curr_max, maximum(slice))
    end

    # Rescale y-axis for the line plot
    autolimits!(axes[end])

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

"""
    update_colorbar(heatmaps_vector::Vector{Heatmap}, minval::Float64, maxval::Float64)

Update heatmap color ranges.

# Arguments
- `heatmaps_vector`: List of heatmap objects.
- `minval`: Minimum value.
- `maxval`: Maximum value.
"""
function update_colorbar(heatmaps_vector::Vector{Heatmap}, minval::Float64, maxval::Float64)
    for heatmap in heatmaps_vector
        heatmap.colorrange[] = (minval, maxval)
    end
end

"""
    update_colorbar_slider_range(colorbar_slider::IntervalSlider, minval::Float64, maxval::Float64)

Update colorbar slider range.

# Arguments
- `colorbar_slider`: Colorbar slider object.
- `minval`: Minimum value.
- `maxval`: Maximum value.
"""
function update_colorbar_slider_range(colorbar_slider::IntervalSlider, minval::Float64, maxval::Float64)
    @debug "Updating colorbar slider range to $(minval) to $(maxval)"
    colorbar_slider.range[] = LinRange(minval, maxval, 300)
end

"""
    update_colorbar_slider_interval(colorbar_slider::IntervalSlider, minval::Float64, maxval::Float64)

Update colorbar slider interval.

# Arguments
- `colorbar_slider`: Colorbar slider object.
- `minval`: Minimum value.
- `maxval`: Maximum value.
"""
function update_colorbar_slider_interval(colorbar_slider::IntervalSlider, minval::Float64, maxval::Float64)
    @debug "Updating colorbar slider interval to $(minval) to $(maxval)"
    set_close_to!(colorbar_slider, minval, maxval)
end

"""
    plot_mismip_plus(files::Vector{String}; output::Union{Nothing, String} = nothing)

Plot MISMIP+ results.

# Arguments
- `files`: List of netCDF files.

# Keywords
- `output=nothing`: Output file path to save the plot. If nothing, the plot will be displayed in an interactive window.
"""
function plot_mismip_plus(files::Vector{String}; output::Union{Nothing, String} = nothing)
    datasets::Vector{Dataset} = [Dataset(f) for f in files] # Open datasets once
    ds = datasets[1]

    fig_width::Int = 1500
    fig_height::Int = 350 * (length(files) + 1)

    # Filter out variables that are not 3D
    varnames::Vector{String} = filter(x -> ndims(ds[x]) == 3, keys(ds))

    xh::Vector{Float64}, yh::Vector{Float64}, TIME::Vector{Float64} = get_coords(ds)

    nt::Int = length(TIME)

    fig::Figure = build_figure(; size = (fig_width, fig_height))

    y_slider,
    axes,
    varname_menu,
    time_slider,
    colorbar_slider,
    lock_toggle,
    min_label,
    max_label = build_interface(fig, yh, TIME, varnames; n_heatmaps = length(files))

    # Initialise plots
    varname::String = varnames[1]

    heatmaps_vector::Vector{Heatmap} = []

    for (i, ds_i) in enumerate(datasets)
        # Initial slice
        data0 = ds_i[varname][:, :, 1]
        heatmap::Heatmap = plot_heatmap(axes[i], xh, yh, data0)
        push!(heatmaps_vector, heatmap)
        axes[i].title = "File: $(files[i])"
    end

    # Add Colourbar
    ## Round float tick values to int (stops axes moving around)
    int_tick(x) = string.(round.(Int, x))
    heatmap_cbar =
        Colorbar(fig[1:length(files), 3], heatmaps_vector[1]; tickformat = int_tick, label = varname)

    heatmap_line_plot::Lines = plot_heatmap_cross_section_line(axes[1], xh, yh)

    # Initialise line plots with Observables
    line_observables::Vector{Observable} = []
    for (i, ds_i) in enumerate(datasets)
        # Initial line data
        line_data = ds_i[varname][:, 1, 1]
        obs = Observable(line_data)
        push!(line_observables, obs)
        lines!(axes[end], xh, obs, label = files[i], linewidth = 2)
    end

    figure_title::Label = Label(
        fig[0, :],
        "$varname at time = $(round(TIME[time_slider.value[]], digits=2))",
        fontsize = 30,
    )

    # Initialise slider range with global limits
    global_min::Float64, global_max::Float64 = get_global_limits(datasets, varname)
    update_colorbar_slider_range(colorbar_slider, global_min, global_max)

    ## Colourbar range setting callback
    on(colorbar_slider.interval) do t::Tuple{Float64, Float64}
        min_label.text = string(round(t[1], digits = 2))
        max_label.text = string(round(t[2], digits = 2))
        update_colorbar(heatmaps_vector, t[1], t[2])
    end

    update_plot(
        axes,
        datasets,
        heatmaps_vector,
        line_observables,
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
    on(varname_menu.selection) do varname::String
        t::Int = time_slider.value[]
        yidx::Int = y_slider.value[]

        if !lock_toggle.active[]
            # Update slider range to new variable's global limits
            global_min, global_max = get_global_limits(datasets, varname)
            update_colorbar_slider_range(colorbar_slider, global_min, global_max)
        end

        update_plot(
            axes,
            datasets,
            heatmaps_vector,
            line_observables,
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
    end

    # Slider callbacks
    ## y slider callback
    on(y_slider.value) do yidx::Int
        varname = varname_menu.selection[]
        t::Int = time_slider.value[]

        # Update red horizontal line on heatmap
        y_line = fill(yh[yidx], length(xh))
        heatmap_line_plot[1][] = Point2f.(xh, y_line)

        update_plot(
            axes,
            datasets,
            heatmaps_vector,
            line_observables,
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
    on(time_slider.value) do t::Int
        varname = varname_menu.selection[]
        yidx::Int = y_slider.value[]

        update_plot(
            axes,
            datasets,
            heatmaps_vector,
            line_observables,
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
