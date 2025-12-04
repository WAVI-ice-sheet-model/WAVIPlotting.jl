> [!WARNING]
> This is an experimental package - use at your own risk!

# WAVIPlotting.jl

A Julia package for plotting ice sheet model netCDF outputs from [WAVI.jl](https://github.com/WAVI-ice-sheet-model/WAVI.jl) for MISMIP+ experiments.

## Installation

### From GitHub

```bash
julia --project=.
```

```julia
using Pkg
Pkg.add(url="https://github.com/WAVI-ice-sheet-model/WAVIPlotting.jl")
Pkg.resolve()
Pkg.instantiate()
```

### For Development

```bash
git clone https://github.com/WAVI-ice-sheet-model/WAVIPlotting.jl.git
cd WAVIPlotting.jl
julia --project=. -e 'using Pkg; Pkg.instantiate()'
```

In this case, since you've cloned the script, you can run it directly from the `bin` directory:

```bash
bin/wavi_plot mismip_plus file1.nc file2.nc -o comparison.jpg --format jpg --dpi 300
```

## Setting up the Command-Line Tool

To use `wavi_plot` from the command line, you need to make the script executable and add it to your PATH:

### Linux/macOS

```bash
chmod +x bin/wavi_plot
export PATH="/path/to/WAVIPlotting.jl/bin:$PATH"
```

Add the export line to your `~/.bashrc` or `~/.zshrc` to make it permanent.

### Alternative: Create a system-wide link

```bash
sudo ln -s /path/to/WAVIPlotting.jl/bin/wavi_plot /usr/local/bin/wavi_plot
```

## Usage
After installing the package, the `wavi_plot` executable is placed in the package's `bin` directory. Add this directory to your `PATH` (or invoke it via its full path) to run the tool. For example:

```bash
# Add the bin directory to PATH (adjust the version path as needed)
export PATH="$HOME/.julia/packages/WAVIPlotting/<version>/bin:$PATH"
# Now you can run the command directly
wavi_plot mismip_plus file1.nc file2.nc -o comparison.jpg --dpi 300
```

Alternatively, you can call the script directly without modifying `PATH`:

```bash
$(julia --project=. -e 'using WAVIPlotting; print(joinpath(dirname(pathof(WAVIPlotting)), "..", "bin", "wavi_plot"))') mismip_plus file1.nc file2.nc
```

> [!NOTE]
> But, using this approach, you cannot pass options to the script like the following examples.

### Command Line

```bash
wavi_plot mismip_plus outputs/output.nc outputs2/output.nc
```

With options:

```bash
wavi_plot mismip_plus file1.nc file2.nc -o comparison.jpg
```

### From Julia REPL/Script

```julia
using WAVIPlotting

# Plot MISMIP+ outputs
plot_mismip_plus(
    ["outputs/output.nc", "outputs2/output.nc"],
    "comparison.jpg",
)
```

## Options

- `--output, -o`: Output file path (default: nothing), if nothing, it will show plot in an interactive window
- `--version, -v`: Show version information
- `--help, -h`: Show help message

## Supported Plot Types

- `mismip_plus`: MISMIP+ ice sheet experiment comparisons

## NetCDF File Requirements

Your NetCDF files should contain the following coordinate variables:
- `x`: x-coordinate
- `y`: y-coordinate
- `TIME`: time coordinate (optional)

And data variables with dimensions `TIME`, `y`, `x`, such as:
- `h`: ice thickness
- `u`: u-component of ice velocity
- `v`: v-component of ice velocity

## Development

> [!WARNING]
> Definitely subject to change as I learn more about Julia!

### Adding New Plot Types

1. Create a new file in `src/plots/`
2. Include it in `src/WAVIPlotting.jl`
3. Add the plot type to the command-line parser
4. Update the README

## License

MIT License

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.
