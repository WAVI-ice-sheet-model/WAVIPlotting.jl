module WAVIPlotting

using ArgParse

export wavi_plot_main

include("plots/mismip_plus.jl")

"""
    parse_commandline()

Parse command line arguments for wavi_plot.
"""
function parse_commandline()
    s = ArgParseSettings(
        description = "WaviPlot: Plotting tool for ice sheet model outputs",
        version = "0.0.1",
        add_version = true,
    )

    @add_arg_table! s begin
        "plot_type"
        help = "Type of plot to generate (e.g., mismip_plus)"
        required = true
        "files"
        help = "NetCDF output files to plot"
        nargs = '+'
        required = true
        "--output", "-o"
        help = "Output image of plot file path (default: nothing), if nothing, show plot in interactive window"
        default = nothing
    end

    return parse_args(s)
end

"""
    wavi_plot_main(args=ARGS)

Main entry point for the wavi_plot command-line tool.
"""
function wavi_plot_main(args = ARGS)
    parsed_args = parse_commandline()

    plot_type = parsed_args["plot_type"]
    files = parsed_args["files"]
    output = parsed_args["output"]

    @info "Plot type: $plot_type"
    @info "Files: $files"
    @info "Output: $output"

    if plot_type == "mismip_plus"
        plot_mismip_plus(files; output = output)
    else
        error("Unknown plot type: $plot_type")
    end

    @info "Press enter to close"
    readline()
end

end
