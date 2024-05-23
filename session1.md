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

### Create a Directory in $SCRATCH for Tutorial Experiments
Enter the following commands to create a directory in `$SCRATCH` for our expeiments.
```
mkdir $SCRATCH/TECA_TUTORIAL
cd $SCRATCH/TECA_TUTORIAL
```

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
    for subdir in ${ERA5_BASE}/e5.oper.an.pl/*; do
        ln -s $subdir/*${var}*.nc ${LINK_DIR}
    done
done

# surface variables
for var in $VARIABLEESFC
do
    echo $var
    for subdir in ${ERA5_BASE}/e5.oper.an.sfc/*; do
        ln -s $subdir/*${var}*.nc ${LINK_DIR}
    done
done

# vertically-integrated variables
for var in $VARIABLESVINTEG
do
    echo $var
    for subdir in ${ERA5_BASE}/e5.oper.an.vinteg/*; do
        ln -s $subdir/*${var}*.nc ${LINK_DIR}/
    done
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
data_root = ./era5_links/
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

Save these blocks together in a single file `era5_combined_dataset.mcf` in `$SCRATCH/TECA_TUTORIAL`:
```
data_root = ./era5_links/
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

####  Test the Multi CF File
Now we use `teca_metadata_probe` to test the file and print information about
it. `teca_metadata_probe` requires MPI and must be run on a compute node. We can
do this in one of two ways:

  1. Use `salloc` to start an interactive session on a compute node.
  2. Submit a batch job using `sbatch`.

An interactive session on a compute node makes debugging easier if errors are
returned. A batch job is usually more effcient and should usually be the
standard way to run analyses on Perlmutter.

##### Interactive Session
First, we start an interactive session on a CPU node by running:
```
salloc --nodes 4 --qos interactive --time 01:00:00 --constraint cpu --account=m1517
```
Once the interactive session has started, as indicated by a message like
```
salloc: Nodes nid[004080,004441,004551,004617] are ready for job
```
and a prompt, we can run `teca_metadata_probe`:
```
time srun -n 512 teca_metadata_probe --input_file era5_combined_dataset.mcf
```

##### Batch Job
First, we create a batch file to run `teca_metadata_probe` called `02_check_dataset.sbatch`:
```
#!/bin/bash
#SBATCH -J check_e5_dataset
#SBATCH --nodes 4
#SBATCH --constraint cpu
#SBATCH --account m1517
#SBATCH --time 00:15:00
#SBATCH -q debug

# load the CPU-only version of teca
module use /global/common/software/m1517/teca/perlmutter_cpu/develop/modulefiles/
module load teca

time srun -n 512 teca_metadata_probe --input_file era5_combined_dataset.mcf
```
Subsequently, we submit this job to the batch queue using:
```
sbatch 02_check_dataset.sbatch 
```
To check the status of the batch job, run the `sqs` command. Once the batch job completed
its run, its output us vailable in a file `slurm-<JOBID>.out`


#### Interpreting the Output of `teca_metadata_probe`
If run succesfully, the `teca_metadata_probe` will summarize file contents like,
```
STATUS: [0:140448307711104] [/pscratch/sd/l/loring/teca_testing/TECA_superbuild/build-cpu-develop-640aea2f/TECA-prefix/src/TECA/alg/teca_normalize_coordinates.cxx:653 5.0.0-262-g640aea2]
STATUS: The y-axis will be transformed to be in ascending order.

A total of 471888 steps available. Using the gregorian calendar. Times are
specified in units of hours since 1900-01-01 00:00:00. The available times
range from 1970-1-1 0:0:0 (613608) to 2023-10-31 22:59:60 (1.0855e+06). The
available data contains: 54 years; 214 seasons; 646 months; 19662 days;

Mesh dimension: 3D
Mesh coordinates: longitude, latitude, level
Mesh extents: 0, 1439, 0, 720, 0, 36
Mesh bounds: 0, 359.75, -90, 90, 1, 1000

14 data arrays available

  Id    Name         Type         Centering     Dimensions                            Shape                      
---------------------------------------------------------------------------------------------------------------
  1     CAPE         NC_FLOAT     point 2D      [time, latitude, longitude]           [471888, 721, 1440]        
  2     Q            NC_FLOAT     point 3D      [time, level, latitude, longitude]    [471888, 37, 721, 1440]    
  3     SP           NC_FLOAT     point 2D      [time, latitude, longitude]           [471888, 721, 1440]        
  4     T            NC_FLOAT     point 3D      [time, level, latitude, longitude]    [471888, 37, 721, 1440]    
  5     TCW          NC_FLOAT     point 2D      [time, latitude, longitude]           [471888, 721, 1440]        
  6     VAR_2T       NC_FLOAT     point 2D      [time, latitude, longitude]           [471888, 721, 1440]        
  7     VIWVE        NC_FLOAT     point 2D      [time, latitude, longitude]           [471888, 721, 1440]        
  8     VIWVN        NC_FLOAT     point 2D      [time, latitude, longitude]           [471888, 721, 1440]        
  9     W            NC_FLOAT     point 3D      [time, level, latitude, longitude]    [471888, 37, 721, 1440]    
  10    Z            NC_FLOAT     point 3D      [time, level, latitude, longitude]    [471888, 37, 721, 1440]    
  11    latitude     NC_DOUBLE    point 1D      [latitude]                            [721]                      
  12    level        NC_DOUBLE    point 1D      [level]                               [37]                       
  13    longitude    NC_DOUBLE    point 1D      [longitude]                           [1440]                     
  14    time         NC_INT       point 0D      [time]                                [471888]                   


real	2m23.139s
user	0m0.055s
sys	0m0.039s
```

The output of the `teca_metadata_probe` command provides detailed information about the dataset being analyzed. Here’s a breakdown of each part of the output:

##### Status Messages
```plaintext
STATUS: [0:140448307711104] [/pscratch/sd/l/loring/teca_testing/TECA_superbuild/build-cpu-develop-640aea2f/TECA-prefix/src/TECA/alg/teca_normalize_coordinates.cxx:653 5.0.0-262-g640aea2]
STATUS: The y-axis will be transformed to be in ascending order.
```
These lines indicate the status of the TECA process. The message specifies that the y-axis (latitude) will be reordered to be in ascending order, which is a common preprocessing step to ensure consistency in the data.

##### Time Information
```plaintext
A total of 471888 steps available. Using the gregorian calendar. Times are specified in units of hours since 1900-01-01 00:00:00. The available times range from 1970-1-1 0:0:0 (613608) to 2023-10-31 22:59:60 (1.0855e+06). The available data contains: 54 years; 214 seasons; 646 months; 19662 days;
```
This section provides information about the temporal coverage of the dataset:

 * **Total Time Steps:** 471888
 * **Calendar Used:** Gregorian
 * **Time Units:** Hours since January 1, 1900, at midnight
 * **Time Range:** From January 1, 1970, to October 31, 2023
 * **Summary of Time Coverage:** 54 years, 214 seasons, 646 months, and 19662 days

###### Mesh Information
```plaintext
Mesh dimension: 3D
Mesh coordinates: longitude, latitude, level
Mesh extents: 0, 1439, 0, 720, 0, 36
Mesh bounds: 0, 359.75, -90, 90, 1, 1000
```
This section describes the spatial structure of the dataset:

 * **Mesh Dimension:** 3D, indicating three spatial dimensions (longitude, latitude, level)
 * **Coordinates:** Longitude, latitude, and level
 * **Mesh Extents:** Indices covering the range of each dimension:
   * Longitude: 0 to 1439
   * Latitude: 0 to 720
   * Level: 0 to 36
 * **Mesh Bounds:** Actual coordinate values covered by the dataset:
   * Longitude: 0 to 359.75 degrees
   * Latitude: -90 to 90 degrees
   * Level: 1 to 1000 units (possibly hPa for atmospheric pressure levels)

###### Data Arrays
```plaintext
14 data arrays available

  Id    Name         Type         Centering     Dimensions                            Shape                      
---------------------------------------------------------------------------------------------------------------
  1     CAPE         NC_FLOAT     point 2D      [time, latitude, longitude]           [471888, 721, 1440]        
  2     Q            NC_FLOAT     point 3D      [time, level, latitude, longitude]    [471888, 37, 721, 1440]    
  3     SP           NC_FLOAT     point 2D      [time, latitude, longitude]           [471888, 721, 1440]        
  4     T            NC_FLOAT     point 3D      [time, level, latitude, longitude]    [471888, 37, 721, 1440]    
  5     TCW          NC_FLOAT     point 2D      [time, latitude, longitude]           [471888, 721, 1440]        
  6     VAR_2T       NC_FLOAT     point 2D      [time, latitude, longitude]           [471888, 721, 1440]        
  7     VIWVE        NC_FLOAT     point 2D      [time, latitude, longitude]           [471888, 721, 1440]        
  8     VIWVN        NC_FLOAT     point 2D      [time, latitude, longitude]           [471888, 721, 1440]        
  9     W            NC_FLOAT     point 3D      [time, level, latitude, longitude]    [471888, 37, 721, 1440]    
  10    Z            NC_FLOAT     point 3D      [time, level, latitude, longitude]    [471888, 37, 721, 1440]    
  11    latitude     NC_DOUBLE    point 1D      [latitude]                            [721]                      
  12    level        NC_DOUBLE    point 1D      [level]                               [37]                       
  13    longitude    NC_DOUBLE    point 1D      [longitude]                           [1440]                     
  14    time         NC_INT       point 0D      [time]                                [471888]     
```
This section lists the data arrays (variables) available in the dataset, including:

 * **Variable ID and Name:** A unique identifier and the variable name (e.g., CAPE, Q, SP)
 * **Type:** Data type (e.g., NC_FLOAT for NetCDF float)
 * **Centering:** Indicates how the data points are centered (point 2D or point 3D)
 * **Dimensions:** The dimensions of the data array, showing which axes the data spans (e.g., time, latitude, longitude)
 * **Shape:** The shape of the data array, indicating the number of points along each dimension

Each variable provides specific atmospheric or surface measurements, such as temperature (T), specific humidity (Q), and vertical velocity (W), among others.
