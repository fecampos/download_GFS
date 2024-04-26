#!/bin/bash

# Get current date
current_date=$(date +"%Y%m%d")

# Define input URL
input_url="https://nomads.ncep.noaa.gov/pub/data/nccf/com/cfs/prod/"

# Create directory to store downloaded files
mkdir -p downloaded_files

# Download index file: ocean
index_file_ocean="cfs.$current_date/00/monthly_grib_01/"
wget -q --no-check-certificate "${input_url}/${index_file_ocean}" -O index_ocean.txt

# Download index file: atmosphere
index_file_atmosphere="cfs.$current_date/00/6hrly_grib_01/"
wget -q --no-check-certificate "${input_url}/${index_file_atmosphere}" -O index_atmosphere.txt

# Extract file names: ocean
grep -e"ocnf."*"${current_date}".*"avrg.grib.grb2" index_ocean.txt | cut -d '>' -f 1 | cut -d '"' -f 2 | sed 's/\.idx$//' | uniq >> file_names_ocean

# Extract file names: atmosphere
grep -e"flxf" index_atmosphere.txt | cut -d '>' -f 1 | cut -d '"' -f 2 | sed 's/\.idx$//' | uniq >> file_names_atmosphere

# Extract file names: pressure
grep -e"pgbf" index_atmosphere.txt | cut -d '>' -f 1 | cut -d '"' -f 2 | sed 's/\.idx$//' | uniq >> file_names_pressure

# Loop through file names and download for the ocean
i=0
while IFS= read -r line; do
    echo $input_url$index_file_ocean$line
    echo $i
    # Download GRIB2 file
    wget -N -c --no-check-certificate $input_url$index_file_ocean$line -P downloaded_files
    # Convert GRIB2 to NetCDF using cdo
    cdo -f nc copy downloaded_files/$line downloaded_files/$line.nc
    # Cut variables from NetCDF: salinity, temperature, u,v, ssh
    ncks -O -v pt,s,ocu,ocv,sshg downloaded_files/$line.nc downloaded_files/$line.nc
    # change temperature and salinity
    ncap2 -O -s "pt=pt-273.15" -s "s=s*1000" -s "time=time+15+30*$i" downloaded_files/$line.nc downloaded_files/$line.nc    
    # add off_set and changing units of temperature
    ncatted -O -h -a add_offset,pt,m,f,25. -a units,pt,m,c,"degrees_C" downloaded_files/$line.nc
    # change name of variables and dimensions
    ncrename -O -v pt,thetao -v s,so -v ocu,uo -v ocv,vo -v sshg,zos -v lon,longitude -v lat,latitude downloaded_files/$line.nc downloaded_files/$line.nc
    ncrename -O -d lon,longitude -d lat,latitude downloaded_files/$line.nc downloaded_files/$line.nc
    # permute depth dimension
    ncpdq -O -a -depth downloaded_files/$line.nc downloaded_files/$line.nc
    # change start time
    cdo -O setreftime,1980-01-01,0,1day -setcalendar,standard downloaded_files/$line.nc downloaded_files/$line"_v02.nc"
    # overwrite data
    mv downloaded_files/$line"_v02.nc" downloaded_files/$line.nc
    i=$(($i + 1))
done < file_names_ocean


i=0
while IFS= read -r line; do
    echo $input_url$index_file_ocean$line
    echo $i
    ncap2 -O -s "time=time+15+30*$i" downloaded_files/$line.nc downloaded_files/$line.nc 
    i=$(($i + 1))
done < file_names_ocean    
    
    
    
    
# Loop through file names and download for the atmosphere
while IFS= read -r line; do
    echo $input_url$index_file_atmosphere$line
    # Download GRIB2 file
    wget -N -c --no-check-certificate $input_url$index_file_atmosphere$line -P downloaded_files
    # Convert GRIB2 to NetCDF using cdo
    cdo -f nc copy downloaded_files/$line downloaded_files/$line.nc
done < file_names_atmosphere

# Loop through file names and download for the pressure
while IFS= read -r line; do
    echo $input_url$index_file_atmosphere$line
    # Download GRIB2 file
    wget -N -c --no-check-certificate $input_url$index_file_atmosphere$line -P downloaded_files
    # Convert GRIB2 to NetCDF using cdo
    cdo -f nc copy downloaded_files/$line downloaded_files/$line.nc
done < file_names_pressure


# Clean up
rm index_*.txt file_names*

