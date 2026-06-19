library(ncdf4)
library(terra)
library(rnaturalearth)
library(rnaturalearthdata)

# Download cru_cl2.nc from Zenodo (DOI to be added after upload)
# and place it in your working directory, then run this script.

ncfile <- "cru_cl2.nc"
nc <- nc_open(ncfile)
print(nc)  # inspect all variables and dimensions

lons <- ncvar_get(nc, "lon")
lats <- ncvar_get(nc, "lat")
world <- ne_countries(scale = "medium", returnclass = "sf")

# --- Example 1: Global map of mean July temperature ---

tmp_rast <- rast(ncfile, subds = "tmp")   # terra reads coordinates directly
plot(tmp_rast[[7]], main = "CRU CL 2.0 — Mean temperature July (°C)")
plot(world$geometry, add = TRUE, border = "white", lwd = 0.5)


# --- Example 2: Point extraction — all variables at one location ---

target_lon <- 133.8807  # Alice Springs, Australia
target_lat  <- -23.6980
xy <- cbind(target_lon, target_lat)

monthly_vars <- c("pre", "rd0", "frs", "tmp", "dtr", "reh", "sunp", "wnd")

point <- data.frame(month = 1:12)
for (v in monthly_vars) {
  r_var      <- rast(ncfile, subds = v)
  point[[v]] <- as.numeric(terra::extract(r_var, xy)[1, ])
}
elv_r     <- rast(ncfile, subds = "elv")
point$elv <- as.numeric(terra::extract(elv_r, xy)[1, 1])

# Derive min/max temperature from tmp and dtr
point$tmin <- point$tmp - point$dtr / 2
point$tmax <- point$tmp + point$dtr / 2

print(point)

par(mfrow = c(2, 1))
plot(point$month, point$tmax, type = "l", col = "red",
     ylim = range(point$tmin, point$tmax),
     xlab = "Month", ylab = "Temperature (°C)",
     main = paste("Alice Springs temperature range (elev", round(point$elv[1]), "m)"))
lines(point$month, point$tmin, col = "blue")
legend("topright", c("Tmax", "Tmin"), col = c("red", "blue"), lty = 1)

plot(point$month, point$pre, type = "h", col = "steelblue",
     xlab = "Month", ylab = "Precipitation (mm)",
     main = "Alice Springs precipitation")


# --- Example 3: All months as a terra SpatRaster ---

nc_close(nc)

pre_rast <- rast(ncfile, subds = "pre")
names(pre_rast) <- month.abb
plot(pre_rast[[c(1, 4, 7, 10)]],
     main = paste("Precipitation", c("Jan", "Apr", "Jul", "Oct"), "(mm)"))
