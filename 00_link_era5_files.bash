#!/bin/bash

# Create result directory that will contain links
LINK_DIR=era5_links/
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
    for subdir in ${ERA5_BASE}/e5.oper.an.sfc; do
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