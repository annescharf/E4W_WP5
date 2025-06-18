# Script for processing NDVI data
# June 2025. Max Planck Institute for Animal Behaviour, DE.
# Anne Scharf, PhD. ascharf@ab.mpg.de
#___________________________________________

library(terra)

# MODIS/Terra Vegetation Indices monthly Global 1km V061 - NDVI and pixel reliability
# Downloaded from earthdata.nasa.gov for the years 2000-2025 (see script "A.earthdata_NDVI_global_download_and_stitching.R")
# Download was done in quarters, stitched to one raster for globe in yearly subfolders
# results from this script are all rasters in one folder named by date
## sample file names
## "MOD13A3.061__1_km_monthly_NDVI_doy2000061000000_aid0001.tif"
## "MOD13A3.061__1_km_monthly_pixel_reliability_doy2000061000000_aid0001.tif"
## filtered raster will be saved as:
## "20000301.tif" # date: "2000-03-01"

genPath <- "~/Documents/Projects/NDVI_monthly/"
dir.create(paste0(genPath,"global_MOD13A3.061__1_km_monthly_NDVI"))
clnPth <- paste0(genPath,"global_MOD13A3.061__1_km_monthly_NDVI/")

### pixel_reliability 
# # 0	Good data, use with confidence
# # 1	Marginal data, Useful, but look at other QA information
# # 2	Snow/Ice Target covered with snow/ice
# # 3	Cloudy data, Target not visible, covered with cloud


yrs <- 2006:2025
# yr <- 2001
lapply(yrs, function(yr){
  print(yr)
  
  flsNs <- list.files(paste0(genPath,yr,"/"), pattern="_NDVI_", full.names = F)
  ydoyVctr <- gsub(".*doy([0-9]+)_.*", "\\1", flsNs) # extracting year doy date 
  # ydoy <- ydoyVctr[1]
  lapply(ydoyVctr, function(ydoy){
    ndvi <- rast(list.files(paste0(genPath,yr,"/"),pattern=paste0("NDVI_doy",ydoy), full.names = T))
    pxreliab <- rast(list.files(paste0(genPath,yr,"/"),pattern=paste0("pixel_reliability_doy",ydoy), full.names = T))
    
    # mask only clouds, snow/ice kept to its original values for now
    ndvi[pxreliab == 3] <- NA # cloud
    
    yr_doy <- sub("^([0-9]{4})(.*)", "\\1-\\2", ydoy) ## separating year and doy
    dte <- as.Date(yr_doy, format = "%Y-%j") ## converting to date
    flname <- gsub("-","",dte) ## converting date to filename format
    writeRaster(ndvi, paste0(clnPth,flname,".tif"), overwrite=T, datatype="FLT4S")
  })
  
})