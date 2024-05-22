# NERSC TECA Tutorial

# Topics Covered
- **Introduction to TECA**: We begin with an overview of TECA, outlining its role in analyzing large-scale climate data.

- **Metadata Probe**: We introduce Metadata Probe, a tool for summarizing datasets and planning computational jobs. It helps us understand data structure and plan tasks efficiently.

- **Data Preprocessing**: We walk through data preprocessing steps, including creating Metadata Control Files (MCF) and organizing data files from multiple directories for efficient access.

- **Parallel Processing**: We highlight the importance of parallel processing and demonstrate how TECA distributes tasks across multiple processors for improved efficiency.

- **Debugging and Troubleshooting**: We emphasize the need to examine metadata outputs for anomalies, aiding in debugging and troubleshooting errors during data analysis.

- **Application in Climate Research**: Throughout, we refer to real-world applications of TECA in climate research, showcasing its relevance and effectiveness in studying extreme weather events and climate phenomena.

# Prerequisites
This tutorial assumes that participants

 * are proficient in the use of Unix-type command line systems
 * have some familiarity with programming (Python experience isn’t strictly necessary; if you know R, for example, the skills should be transferable for this tutorial)
 * have some experience with netCDF-based climate data
 * have accounts on NERSC
 * have access to data in the `m3522` CFS directory at NERSC

## Introduction to TECA
TECA, or Toolkit for Extreme Climate Analysis, is a software framework designed
to facilitate the analysis of large-scale climate data, particularly focusing on
extreme weather events. Its primary purpose is to provide tools for processing,
analyzing, and visualizing complex atmospheric and oceanographic datasets. TECA
offers a range of functionalities, including data preprocessing, feature
detection, statistical analysis, and visualization, tailored to address the
challenges of climate research.

One of the key features of TECA is its ability to handle massive datasets
efficiently, leveraging parallel computing techniques to process and analyze
large volumes of data in a scalable manner. This capability makes TECA
well-suited for studying extreme weather phenomena, such as hurricanes,
heatwaves, and atmospheric rivers, which require detailed analysis of extensive
spatiotemporal data.

Overall, TECA serves as a comprehensive toolkit for researchers and scientists
working in climate science and related fields, providing the necessary tools and
techniques to explore, understand, and interpret complex climate data.

## Connecting to NERSC and Loading the TECA Module

To connect to NERSC, specifically Perlmutter, and load the TECA module, you can follow these steps:

1. **SSH into Perlmutter**: Use SSH to connect to Perlmutter by running the following command in your terminal:
   ```bash
   ssh username@saul.nersc.gov
   ```
   Replace `username` with your actual NERSC username.

2. **Authenticate**: Enter your NERSC password when prompted to authenticate.

3. **Load TECA module**: Once connected to Perlmutter, load the TECA module by running:
   ```bash
   module use /global/common/software/m1517/teca/perlmutter_cpu/develop/modulefiles/
   module load teca
   ```
   This command will provide you with the necessary environment to use TECA without needing to compile it yourself.

With these steps, you should be connected to NERSC's Perlmutter system and have the TECA module loaded, ready for use.


## Preparing Data for TECA Analysis

### Example Data Set
In this tutorial we are using the ERA5 data set, which is stored in the NERSC
Community File System (CFS) at `/global/cfs/cdirs/m3522/cmip6/ERA5`. ERA5 is a
global climate reanalysis dataset produced by the European Centre for
Medium-Range Weather Forecasts (ECMWF), offering detailed hourly data on the
Earth's atmosphere, land surface, and ocean waves from 1950 to the present. With
a high spatial resolution of 31 kilometers and covering numerous variables such
as temperature, wind, and precipitation, ERA5 supports climate research, weather
forecasting, environmental monitoring, renewable energy planning, and
hydrological studies. It integrates observations from satellites, ground
stations, and buoys using advanced data assimilation techniques, ensuring
high-quality and consistent data, accessible through the Copernicus Climate
Change Service.

### Create a Directory with Symbolic Links to All Files
First, we need to create a directory with all files required for our analysis.
This is necessary since TECA has a limitation where a single CF (Climate and
Forecast) reader can only handle files within a single directory. By creating a
directory with symbolic links to the necessary NetCDF files, we ensure all the
files are accessible from a single location.

Copy the following code into a file `00_link_era5_files.bash` and use `chmod a+x 00_link_era5_files.bash` to ensure it is executable.
```bash:00_link_era5_files.bash
#!/bin/bash

# Create result directory that will contain links
LINK_DIR=$SCRATCH/TECA_TUTORIAL/era5_links/
mkdir -p ${LINK_DIR}

# Location of files to link
ERA5_BASE="/global/cfs/cdirs/m3522/cmip6/ERA5"

# set the variables to analyze
VARIABLES3D="128_129_z 128_130_t 128_133_q 128_135_w"
VARIABLEESFC="128_134_sp 128_136_tcw 128_059_cape 128_167_2t"
VARIABLESVINTEG="162_071_viwve 162_072_viwvn"

# error-out on any failure
set -e 

# 3D variables
for var in $VARIABLES3D
do
    echo $var
    ln -s ${ERA5_BASE}/e5.oper.an.pl/*/*${var}*.nc ${LINK_DIR}
done

# surface variables
for var in $VARIABLEESFC
do
    echo $var
    ln -s ${ERA5_BASE}/e5.oper.an.sfc/*/*${var}*.nc ${LINK_DIR}
done

# vertically-integrated variables
for var in $VARIABLESVINTEG
do
    echo $var
    ln -s ${ERA5_BASE}/e5.oper.an.vinteg/*/*${var}*.nc ${LINK_DIR}/
done

# write the link directory name to the terminal for checking in the MCF file
echo 'Make sure that the `data_root` directory in the MCF file matches the directory below:'
echo `realpath $LINK_DIR`
```

### Create a Multi CF File
In this step, we manually create a MCF (multi cf, as in 'CF conventions') netCDF
reader file; this tells TECA where to find all the various variables to use in
the analysis.

Here's an explanation of an example MCF file for TECA:
```
data_root = $SCRATCH/TECA_TUTORIAL/era5_links/
regex = \.ll025.*\.nc$

x_axis_variable = longitude
y_axis_variable = latitude
z_axis_variable = level
clamp_dimensions_of_one = 1
```

- **data_root**: Specifies the root directory where the data files are located.
- **regex**: Defines the regular expression pattern for matching NetCDF files.
- **x_axis_variable**: Specifies the variable representing the x-axis (longitude).
- **y_axis_variable**: Specifies the variable representing the y-axis (latitude).
- **z_axis_variable**: Specifies the variable representing the z-axis (level).
- **clamp_dimensions_of_one**: Indicates whether to treat dimensions of size one specially (e.g., by collapsing them).

Each `[cf_reader]` block defines how to read specific variables from the NetCDF files:
```
[cf_reader]
variables = T
regex = %data_root%/.*128_130_t%regex%
provides_time
provides_geometry
```
- **variables**: Lists the variables to be read (e.g., T for temperature).
- **regex**: Constructs the file path using the `data_root` and `regex` patterns, specifying which files to read for this variable.
- **provides_time**: Indicates that this variable provides time information.
- **provides_geometry**: Indicates that this variable provides spatial geometry information.

Additional `[cf_reader]` blocks follow the same structure to define how to read other variables:
```
[cf_reader]
variables = Z
regex = %data_root%/.*128_129_z%regex%

[cf_reader]
variables = Q
regex = %data_root%/.*128_133_q%regex%

[cf_reader]
variables = W
regex = %data_root%/.*128_135_w%regex%

[cf_reader]
variables = VAR_2T
regex = %data_root%/.*128_167_2t%regex%
z_axis_variable = ""

[cf_reader]
variables = SP
regex = %data_root%/.*128_134_sp%regex%
z_axis_variable = ""

[cf_reader]
variables = TCW
regex = %data_root%/.*128_136_tcw%regex%
z_axis_variable = ""

[cf_reader]
variables = CAPE
regex = %data_root%/.*128_059_cape%regex%
z_axis_variable = ""

[cf_reader]
variables = VIWVE
regex = %data_root%/.*162_071_viwve%regex%
z_axis_variable = ""

[cf_reader]
variables = VIWVN
regex = %data_root%/.*162_072_viwvn%regex%
z_axis_variable = ""
```
- **variables**: Different variables such as Z (geopotential), Q (specific humidity), W (vertical velocity), etc.
- **z_axis_variable**: For surface variables like VAR_2T, SP, TCW, CAPE, VIWVE, and VIWVN, `z_axis_variable` is set to an empty string to indicate that these variables do not have a vertical dimension.

Each `[cf_reader]` block provides a clear mapping of variables to their respective file patterns, enabling TECA to read and process the data correctly.

Save these blokcs together in a single file `era5_combined_dataset.mcf` in `$SCRATCH/TECA_TUTORIAL`:
```
data_root = $SCRATCH/TECA_TUTORIAL/era5_links/
regex = \.ll025.*\.nc$

x_axis_variable = longitude
y_axis_variable = latitude
z_axis_variable = level
clamp_dimensions_of_one = 1

[cf_reader]
variables = T
regex = %data_root%/.*128_130_t%regex%
provides_time
provides_geometry

[cf_reader]
variables = Z
regex = %data_root%/.*128_129_z%regex%

[cf_reader]
variables = Q
regex = %data_root%/.*128_133_q%regex%

[cf_reader]
variables = W
regex = %data_root%/.*128_135_w%regex%

[cf_reader]
variables = VAR_2T
regex = %data_root%/.*128_167_2t%regex%
z_axis_variable = ""

[cf_reader]
variables = SP
regex = %data_root%/.*128_134_sp%regex%
z_axis_variable = ""

[cf_reader]
variables = TCW
regex = %data_root%/.*128_136_tcw%regex%
z_axis_variable = ""

[cf_reader]
variables = CAPE
regex = %data_root%/.*128_059_cape%regex%
z_axis_variable = ""

[cf_reader]
variables = VIWVE
regex = %data_root%/.*162_071_viwve%regex%
z_axis_variable = ""

[cf_reader]
variables = VIWVN
regex = %data_root%/.*162_072_viwvn%regex%
z_axis_variable = ""
```

#### 
After loading the TECA module, you can test it by running the `teca_metadata_probe` command on a sample NetCDF file. Here are the steps:

1. **Prepare a Sample NetCDF File**: Ensure you have a sample NetCDF file available in your working directory on Perlmutter. For this example, let's assume the file is named `sample_data.nc`.

2. **Run `teca_metadata_probe`**: Execute the following command to probe the metadata of the NetCDF file:
   ```bash
   teca_metadata_probe --input_file sample_data.nc
   ```

3. **Example Output**: The command should produce an output similar to the following, displaying the metadata information of the NetCDF file:
   ```plaintext
   teca_metadata_probe: 1.9.0
   input_file = sample_data.nc
   --- BEGIN REPORT ---
   teca_metadata_probe (rank 0):
   file = sample_data.nc
   n_variables = 3
   variables = [
       "temperature",
       "pressure",
       "humidity"
   ]
   n_dimensions = 3
   dimensions = [
       "time",
       "latitude",
       "longitude"
   ]
   --- END REPORT ---
   ```

4. **Interpreting the Output**: The output provides a summary of the metadata in the NetCDF file, including the variables and dimensions present in the file.

With these steps, you can successfully test TECA on NERSC's Perlmutter by probing the metadata of a sample NetCDF file.