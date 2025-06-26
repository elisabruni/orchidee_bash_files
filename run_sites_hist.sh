#!/bin/bash

#------------------------------------------
#to run this bash script: . run_sites_hist.sh
#------------------------------------------
#############################################################################
#This script runs orchidee (v2) based on a predefined configuration directory
#For multiple sites
#It copies the default configuration directory
#Modifies lon-lat and jobname
#Defines the directory path where to store the output files
#Creates the job
#And runs it on obelix
#############################################################################
#This configuration only runs "crop" sites
#from 1959 to 2021
#for pft: SECHIBA_VEGMAX__12=1.0, rest =0

####################
#---you need to---- 
######################
#
# 1. Set your username
#
######################
#======================
my_username="ebruni"
#======================
###########################
#
# 2. Set your directory paths
#
###########################

#======================#======================#======================
#Set directory where you want your output files to be stored
DIRout="/home/surface7/${my_username}/ORCHIDEEv2/"
#Set directory where your configuration files will be copied
DIRsimu="${DIRout}modipsl/config/ORCHIDEE_OL"
#Set your default condiguration folder that will be copied to make new configurations
DIR_DEFAULT_CONFIG_hist="$DIRsimu/FR_SAFRAN_HIST"
#Set your restart path (where the spinup is located)
DIRrest="${DIRout}IGCM_OUT/OL2/TEST/spinup"
#======================#======================#======================

#Print them if you want
#echo "$DIRout"
#echo "$DIRsimu"
#echo "$DIR"
#echo "$DIR_DEFAULT_CONFIG_hist"
#return 1

##################################################
#
# 3.  provide a csv file with following columns: 
#
##################################################
#   ===================================================
#   site_code,country,research_theme,longitude,latitude
#   ===================================================
#   Ex:
#   EFELEPROs,France,crop,-1.794066,48.108742
#
#   (research_theme = land-use)

##################################################
#
# 4.  provide name of the csv file: 
#
##################################################

#======================#======================
#CSV_FILE="site_metadata_forORCHIDEE_France.csv"
CSV_FILE="site_metadata_forORCHIDEE_France_hist.csv"
#======================#======================

#########################################################
# YOU DONT HAVE ANYTHING ELSE TO DO
#########################################################

# Change directory to where configurations are
cd "$DIR" || { echo "Error: Unable to change to directory $DIR"; return 1; }

# Check if the CSV file exists
if [[ ! -f $CSV_FILE ]]; then
  echo "Error: CSV file '$CSV_FILE' not found!"
  return 1
fi

#Convert csv file to unix csv format to remove spaces at the end of line (if needed)
dos2unix "${CSV_FILE}"
#If you want to print the csv file, run this command
#cat -A "${CSV_FILE}"

# Read the CSV file line by line, skipping the header
awk 'NR>1 {print $0}' "$CSV_FILE" | while IFS=',' read -r site_code country research_theme longitude latitude; do
  # Ensure the variables are not empty
  if [[ -z "$site_code" || -z "$country" || -z "$research_theme" || -z "$longitude" || -z "$latitude" ]]; then
    echo "Skipping invalid line (missing data): $site_code, $country, $research_theme, $longitude, $latitude"
    continue
  fi

  # Skip lines where research_theme is "ltbf" == longterm bare fallow
  #if [[ "$research_theme" == "LTBF" ]]; then
  #  echo "Skipping line with research_theme 'ltbf': $site_code, $country, $research_theme, $longitude, $latitude"
  #  continue
  #fi

  #This makes sure to remove "_" and "." from site names (otherwise job cannot be created with this name)
  site_code="${site_code//[_.]}"

  # Print for debugging
  echo "Processing site: $site_code, Country: $country, Research Theme: $research_theme, Longitude: $longitude, Latitude: $latitude"
  echo " "
  
    
  # Convert longitude and latitude to numeric values
  lon=$(echo "$longitude" | xargs)
  lat=$(echo "$latitude" | xargs)

  #echo "$lon"
  #echo "$lat"

  #return 1

  #Copy the default configuration and create a new one for the current site
  #If file already exists, it will overwrite
  cp -rf "${DIR_DEFAULT_CONFIG_hist}" "${DIRsimu}/${site_code}_hist"

  #Go into new configuration directory
  cd "${DIRsimu}/${site_code}_hist" || { echo "Error: Unable to change to directory "${DIRsimu}/${site_code}_hist""; return 1; }

  echo "#######################################"
  echo "Moved to ${site_code}_hist directory"
  echo "#######################################"
  echo " "

  #Add remove Job, Script_output
  #Remove any existing Job file or Script_output file to clean up the directory

  rm -f Script_Output*
  rm -f Job_*

  echo "#######################################"
  echo "Removed all Script_Output* and Job_* files"
  echo "#######################################"
  echo " "


  #Clean the directory
  #./../../../libIGCM/purge_simulation.job

  #echo "Directory cleaned"
  #echo " "

  
  # Update run.def with lon-lat
  sed -i "30c LIMIT_WEST=  $(echo "$lon-0.2" | bc)" "${DIRsimu}/${site_code}_hist/PARAM/run.def"
  sed -i "31c LIMIT_NORTH=  $(echo "$lat+0.2" | bc)" "${DIRsimu}/${site_code}_hist/PARAM/run.def"
  sed -i "32c LIMIT_SOUTH=  $(echo "$lat-0.2" | bc)" "${DIRsimu}/${site_code}_hist/PARAM/run.def"
  sed -i "33c LIMIT_EAST=  $(echo "$lon+0.2" | bc)" "${DIRsimu}/${site_code}_hist/PARAM/run.def"

  echo "#######################################"
  echo "Modified run.def with new lon-lat coordinates"
  echo "#######################################"
  echo " "


  # Update config_card with site-specific Jobname
  sed -i "15c JobName=Hist${site_code}" "${DIRsimu}/${site_code}_hist/config.card"

  echo "#######################################"
  echo "Jobname changed in config.card for site: ${site_code}"
  echo "#######################################"
  echo " "

  # Update config_card with site-specific RestartJobName
  sed -i "72c RestartJobName=Spinup${site_code}" "${DIRsimu}/${site_code}_hist/config.card"

  echo "#######################################"
  echo "RestartJobName set in config.card to:"
  echo "Spinup${site_code}"
  echo "#######################################"
  echo " "

  # Update config_card with RestartPath
  sed -i "75c RestartPath=${DIRrest}" "${DIRsimu}/${site_code}_hist/config.card"

  echo "#######################################"
  echo "RestartPath set in config.card to:"
  echo "${DIRrest}"
  echo "#######################################"
  echo " "

  # Update config_card to specify where you want your outputs to be stored
  sed -i "23a ARCHIVE = ${DIRout}" "${DIRsimu}/${site_code}_hist/config.card"

  echo "#######################################"
  echo "Directory path for output files set to:"
  echo "${DIRout}"
  echo "#######################################"
  echo " "

  # Execute commands
  #Insert job for this site
  ./../../../libIGCM/ins_job  || { echo "Error: Unable to insert job "; return 1; }

  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"  
  echo "job created for site ${site_code}"
  echo "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!"
  echo " "

  #Submit the job
  qsub "Job_Hist${site_code}" || { echo "Error: Unable to insert job "; return 1; }

  echo "!!!!!!!!!!!!!!!!!!"
  echo "CONGRATS: job run"
  echo "!!!!!!!!!!!!!!!!!!"  
  echo " "

  echo "Processed site: $site_code (lon: $lon, lat: $lat)"
  echo " "

  #Check job status
  echo "................................."
  echo "Now you can check your job status"
  echo "with qstat -u username"
  echo "................................."
  qstat -u "${my_username}"
  
  #Return to main DIR
  cd "$DIR" || { echo "Error: Unable to change to directory $DIR"; return 1; }

done

echo "All sites processed."
