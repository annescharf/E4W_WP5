# Script for downloading NDVI data
# June 2025. Max Planck Institute for Animal Behaviour, DE.
# Anne Scharf, PhD. ascharf@ab.mpg.de
#___________________________________________


##################################################
#### downloading rasters from NASA earth data ####
##################################################

library(appeears)
## vignette: https://cran.r-project.org/web/packages/appeears/vignettes/appeears_vignette.html

options(keyring_backend="file") # at least on ubuntu this is needed. You will have to provide a pw for keyring that will be asked for every session you need to access your credentials

## this only needs to be run once, to store the credentials in keyring, after that only the pw of keyring will be asked for
rs_set_key(
  user = "earthdata_username",
  password = "earthdata_pw"
)

## find out with products are available
products <- rs_products()
# Example: MOD13A3.061 is a common global monthly NDVI product

## find out which layers are availabe for a chosen product
ndvi_layers <- rs_layers("MOD13A3.061")
print(ndvi_layers)


### define the polygon of the area of interest. You can also read in a polygon. It must be a sf object (sfc needs to be converted to sf)

library(sf)
## the entire globe cannot be downloaded. Half a globe also does not work, but quarter globe workes nicely
## defining one polygon per quarter globe
roiNE <- st_as_sf(data.frame(
  id = "NE",
  geom = "POLYGON((0 0, 180 0, 180 90, 0 90, 0 0))"
  ),wkt = "geom", crs = 4326)

roiNW <- st_as_sf(data.frame(
  id = "NW",
  geom = "POLYGON((-180 0, 0 0, 0 90, -180 90, -180 0))"
),wkt = "geom", crs = 4326)

roiSE <- st_as_sf(data.frame(
  id = "SE",
  geom = "POLYGON((0 -90, 180 -90, 180 0, 0 0, 0 -90))"
),wkt = "geom", crs = 4326)

roiSW <- st_as_sf(data.frame(
  id = "SW",
  geom = "POLYGON((-180 -90, 0 -90, 0 0, -180 0, -180 -90))"
),wkt = "geom", crs = 4326)



## defining start and end years and which layers to download
yrs <- 2000:2025
startT <- paste0(yrs,"-01-01")
startT[startT=="2000-01-01"] <- "2000-02-01" ## terra modis ndvi data starts here
endT <- paste0(yrs,"-12-31")
endT[endT=="2025-12-31"] <- "2025-05-31" ## Today is June 9th
myproduct <- "MOD13A3.061"
mylayers <- c("_1_km_monthly_NDVI", "_1_km_monthly_pixel_reliability")

## creating data.frames with details of query. A folder will be created with the same name as given in the argument "task". Make sure these are unique for each query.

dfNE_list <- list()
for(i in 1:length(yrs)){
  dfNE_list[[paste0("dfNE_", yrs[i])]] <- data.frame(
    task = paste0("NE_", yrs[i]), ## a folder will be created with this name when the data are downloaded
    subtask = "global_ndvi",
    start = startT[i],
    end = endT[i],
    product = myproduct,
    layer = mylayers
  )
}

dfNW_list <- list()
for(i in 1:length(yrs)){
  dfNW_list[[paste0("dfNW_", yrs[i])]] <- data.frame(
    task = paste0("NW_", yrs[i]),
    subtask = "global_ndvi",
    start = startT[i],
    end = endT[i],
    product = myproduct,
    layer = mylayers
  )
}


dfSE_list <- list()
for(i in 1:length(yrs)){
  dfSE_list[[paste0("dfSE_", yrs[i])]] <- data.frame(
    task = paste0("SE_", yrs[i]),
    subtask = "global_ndvi",
    start = startT[i],
    end = endT[i],
    product = myproduct,
    layer = mylayers
  )
}

dfSW_list <- list()
for(i in 1:length(yrs)){
  dfSW_list[[paste0("dfSW_", yrs[i])]] <- data.frame(
    task = paste0("SW_", yrs[i]),
    subtask = "global_ndvi",
    start = startT[i],
    end = endT[i],
    product = myproduct,
    layer = mylayers
  )
}


# Build the task with the ROI

seq5yrs <- seq(1,length(yrs),by=4) ### dividing years into chuncks of 3, -- total time 48h, for 12 workers, each hast 4h... hopefully enough

# lapply(seq5yrs, function(y){ ## keeps giving error, introducing manually "y". for some reason the looping does not work as hopped
y <- 21
task_list <- lapply(y:(y+3),function(i){
  list(
rs_build_task(df = dfNE_list[[i]], roi = roiNE),#, format="netcdf4") ## netcdf4 files do not contain the date in the name, but has to be looked up in a separate table (in a not straight forward way). It is a bit lighter, but the probability of messing up dates was to high for me
rs_build_task(df = dfNW_list[[i]], roi = roiNW),#, format="netcdf4")
rs_build_task(df = dfSE_list[[i]], roi = roiSE),#, format="netcdf4")
rs_build_task(df = dfSW_list[[i]], roi = roiSW)#, format="netcdf4")
)
})
flat_task_list <- unlist(task_list, recursive = FALSE)

# t0 <- Sys.time()
rs_request_batch(
  request_list= flat_task_list, #task_l
  user = "akscharf",
  path = "/home/ascharf/Documents/Projects/NDVI_monthly/quarters/",
  time_out=14400, #4h
  workers=12, # max 20
  verbose = TRUE,
  total_timeout=172800 # max 48h
)
# Sys.time()-t0

# })

## ERRORS:
# Error in if (private$status != "done") { : argument is of length zero
## this error mostly (but not always) comes if one deletes a download in the appeears webpage. Than the request will be processed, but never downloaded to your pc

## check status of request: https://appeears.earthdatacloud.nasa.gov/explore
## do not delete anything while the R script is still running!


#####################################
#### merging the global quarters #####
#####################################

### NDVI -> FLT4S (datatype)
# # 0.3-1 -- vegetation
# # 0-0.3 -- bare soil
# # neg -- no data (??)

### pixel_reliability -> INT1U (datatype)
# # 0	Good data, use with confidence
# # 1	Marginal data, Useful, but look at other QA information
# # 2	Snow/Ice Target covered with snow/ice
# # 3	Cloudy data, Target not visible, covered with cloud


library(terra)
finalpath <- "~/Documents/Projects/NDVI_monthly/"
qpath <- "~/Documents/Projects/NDVI_monthly/quarters/"
yrs <- 2000:2025

# yr <- 2001
lapply(yrs, function(yr){
  print(yr)
  dir.create(paste0(finalpath,yr))
  
  ## ndvi 
  flsNs <- list.files(paste0(qpath,"NE_",yr,"/"), pattern="_NDVI_", full.names = F)
  fldrsNs <- paste0(c("NE_","NW_","SE_","SW_"),yr)
  r_pth <- paste0(qpath,fldrsNs)
  
  # mth <- flsNs[1]
  lapply(flsNs, function(mth){
    pthL <- paste0(r_pth,"/",mth)
    rstL <- lapply(pthL, rast)
    mm <- mosaic(rstL[[1]],rstL[[2]],rstL[[3]],rstL[[4]], 
                 fun="first",filename=paste0(finalpath,yr,"/",mth), overwrite=T,
                 wopt=list(datatype="FLT4S"))
    # plot(mm)
  })
  
  ## pixel_reliability 
  R_flsNs <- list.files(paste0(qpath,"NE_",yr,"/"), pattern="_pixel_reliability", full.names = F)
  R_fldrsNs <- paste0(c("NE_","NW_","SE_","SW_"),yr)
  R_r_pth <- paste0(qpath,R_fldrsNs)
  
  # mth <- R_flsNs[1]
  lapply(R_flsNs, function(mth){
    R_pthL <- paste0(R_r_pth,"/",mth)
    R_rstL <- lapply(R_pthL, rast)
    R_mm <- mosaic(R_rstL[[1]],R_rstL[[2]],R_rstL[[3]],R_rstL[[4]], 
                   fun="first",filename=paste0(finalpath,yr,"/",mth), overwrite=T,
                   wopt=list(datatype="INT1U"))
    # plot(R_mm)
  })
})