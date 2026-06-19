library(terra)
library(ncdf4)
library(R.utils)

# Downloads CRU CL 2.0 ASCII data and converts to a CF-compliant NetCDF.
#
# Source: New, M., Lister, D., Hulme, M. and Makin, I., 2002:
#   A high-resolution data set of surface climate over global land areas.
#   Climate Research 21:1-25
#   https://crudata.uea.ac.uk/~timm/grid/CRU_CL_2_0.html
#
# License: freely used for non-commercial scientific and educational purposes
# provided it is described as CRU CL 2.0 and attributed to New et al. 2002.

folder <- "cru_cl2_data/"
if (!dir.exists(folder)) dir.create(folder)

sourcepath <- "https://crudata.uea.ac.uk/cru/data/hrg/tmc/"

# Variable definitions: abbr, long name, units, scale factor in raw file
# scale = factor applied in raw .dat file relative to stored units
# (elv is in km in raw file; all others are in native units)
var_defs <- list(
  elv  = list(long = "elevation",                 units = "m",    n_months = 0),
  pre  = list(long = "precipitation",             units = "mm",   n_months = 12),
  rd0  = list(long = "wet-day frequency",         units = "days", n_months = 12),
  frs  = list(long = "frost-day frequency",       units = "days", n_months = 12),
  tmp  = list(long = "mean temperature",          units = "C",    n_months = 12),
  dtr  = list(long = "diurnal temperature range", units = "C",    n_months = 12),
  reh  = list(long = "relative humidity",         units = "%",    n_months = 12),
  sunp = list(long = "sunshine percentage",       units = "%",    n_months = 12),
  wnd  = list(long = "wind speed",               units = "m s-1", n_months = 12)
)

# 10-min grid: 2160 x 1080 cells
gridout <- terra::rast(ncol = 2160, nrow = 1080, xmin = -180, xmax = 180, ymin = -90, ymax = 90)
res_deg <- 1 / 6  # 10 minutes in degrees

lons <- seq(-180 + res_deg / 2, 180 - res_deg / 2, by = res_deg)  # 2160 values
lats <- seq(-90  + res_deg / 2,  90 - res_deg / 2, by =  res_deg)  # 1080 values, S to N (CF ascending)

# Download and decompress all variable files
options(timeout = 600)  # large files on a slow server; default 60s is too short
cat("Downloading CRU CL 2.0 data files...\n")
for (abbr in names(var_defs)) {
  gz_file  <- paste0(folder, "grid_10min_", abbr, ".dat.gz")
  dat_file <- paste0(folder, "grid_10min_", abbr, ".dat")
  if (!file.exists(dat_file)) {
    url <- paste0(sourcepath, "grid_10min_", abbr, ".dat.gz")
    download.file(url, gz_file, mode = "wb", quiet = FALSE)
    R.utils::gunzip(gz_file, remove = TRUE)
    cat(abbr, "downloaded and decompressed\n")
  } else {
    cat(abbr, ".dat already present, skipping download\n")
  }
}

# Parse each variable and rasterize
cat("Rasterizing variables...\n")
rasters <- list()
for (abbr in names(var_defs)) {
  def <- var_defs[[abbr]]
  dat_file <- paste0(folder, "grid_10min_", abbr, ".dat")
  cat("Processing", abbr, "...\n")
  raw <- read.table(dat_file)
  # Column layout: col1 = lat, col2 = lon, col3+ = monthly values (or single for elv)
  coords <- cbind(raw[, 2], raw[, 1])  # lon, lat for terra::rasterize

  if (def$n_months == 0) {
    # elevation: raw values are in km, convert to m
    r <- terra::rasterize(coords, gridout, raw[, 3] * 1000)
    names(r) <- abbr
    rasters[[abbr]] <- r
  } else {
    layers <- vector("list", 12)
    for (m in 1:12) {
      layers[[m]] <- terra::rasterize(coords, gridout, raw[, 2 + m])
    }
    r <- terra::rast(layers)
    names(r) <- month.abb
    rasters[[abbr]] <- r
  }
  rm(raw)
  gc()
  cat(abbr, "done\n")
}

# Build CF-compliant NetCDF
cat("Building NetCDF...\n")

dim_lon   <- ncdim_def("lon",   "degrees_east",  lons)
dim_lat   <- ncdim_def("lat",   "degrees_north", lats)
dim_month <- ncdim_def("month", "1",             1:12,
                       longname = "month of year (1 = January)")

nc_vars <- list()

# Elevation: (lon, lat)
if ("elv" %in% names(rasters)) {
  nc_vars[["elv"]] <- ncvar_def(
    "elv", "m",
    dim         = list(dim_lon, dim_lat),
    missval     = NA_real_,
    longname    = "elevation",
    prec        = "float",
    compression = 5
  )
}

# Monthly variables: (lon, lat, month)
monthly_abbrs <- setdiff(names(rasters), "elv")
for (abbr in monthly_abbrs) {
  def <- var_defs[[abbr]]
  nc_vars[[abbr]] <- ncvar_def(
    abbr, def$units,
    dim         = list(dim_lon, dim_lat, dim_month),
    missval     = NA_real_,
    longname    = def$long,
    prec        = "float",
    compression = 5
  )
}

ncfile <- "cru_cl2.nc"
ncout  <- nc_create(ncfile, nc_vars)

# Write elevation
if ("elv" %in% names(rasters)) {
  rl  <- rasters[["elv"]]
  mat <- matrix(values(rl), nrow = nrow(rl), ncol = ncol(rl), byrow = TRUE)
  mat <- mat[nrow(mat):1, ]   # flip N-to-S → S-to-N to match lat coordinate
  ncvar_put(ncout, nc_vars[["elv"]], t(mat))
}

# Write monthly variables
for (abbr in monthly_abbrs) {
  r   <- rasters[[abbr]]
  arr <- array(NA_real_, dim = c(length(lons), length(lats), 12))
  for (m in 1:12) {
    mat <- matrix(values(r[[m]]), nrow = nrow(r[[m]]), ncol = ncol(r[[m]]), byrow = TRUE)
    mat <- mat[nrow(mat):1, ]  # flip N-to-S → S-to-N to match lat coordinate
    arr[, , m] <- t(mat)
  }
  ncvar_put(ncout, nc_vars[[abbr]], arr)
  cat("Written", abbr, "to NetCDF\n")
}

# Global attributes
ncatt_put(ncout, 0, "title",       "CRU CL 2.0 — 10-minute global land surface climatology (1961–1990)")
ncatt_put(ncout, 0, "source",      "https://crudata.uea.ac.uk/~timm/grid/CRU_CL_2_0.html")
ncatt_put(ncout, 0, "reference",   "New, M., Lister, D., Hulme, M. and Makin, I., 2002: A high-resolution data set of surface climate over global land areas. Climate Research 21:1-25")
ncatt_put(ncout, 0, "license",     "Freely used for non-commercial scientific and educational purposes; attribute as CRU CL 2.0 (New et al. 2002)")
ncatt_put(ncout, 0, "Conventions", "CF-1.8")
ncatt_put(ncout, 0, "created_by",  paste("make_cru_cl2_nc.R, R", R.version$major, R.version$minor))

# Coordinate attributes
ncatt_put(ncout, "lon",   "axis",          "X")
ncatt_put(ncout, "lon",   "standard_name", "longitude")
ncatt_put(ncout, "lat",   "axis",          "Y")
ncatt_put(ncout, "lat",   "standard_name", "latitude")
ncatt_put(ncout, "month", "axis",          "T")

nc_close(ncout)
cat("Written", ncfile, "\n")
