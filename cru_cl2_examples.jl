using NCDatasets

ncfile = "cru_cl2.nc"
ds = NCDataset(ncfile)

println("\n--- Dimensions ---")
for (name, dim) in ds.dim
    println("  $name: $dim")
end

println("\n--- Variables ---")
for (name, var) in ds
    println("  $name: ", size(var), "  units: ", get(var.attrib, "units", "—"))
end

# Coordinate vectors
lons   = ds["lon"][:]    # degrees_east,  2160 values
lats   = ds["lat"][:]    # degrees_north, 1080 values (N to S)
months = ds["month"][:]  # 1:12

println("\n--- Coordinate ranges ---")
println("  lon:   $(lons[1])° to $(lons[end])°  ($(length(lons)) points)")
println("  lat:   $(lats[1])° to $(lats[end])°  ($(length(lats)) points)")
println("  month: $(months[1]) to $(months[end])")

# --- Example 1: Global slice — July mean temperature ---
tmp_jul = ds["tmp"][:, :, 7]   # lon × lat at month 7
println("\n--- tmp July ---")
println("  size:  ", size(tmp_jul))
println("  range: $(round(minimum(skipmissing(tmp_jul)), digits=1)) — ",
                  "$(round(maximum(skipmissing(tmp_jul)), digits=1)) °C")

# --- Example 2: Point extraction — Alice Springs ---
target_lon, target_lat = 133.8807, -23.6980

ilon = argmin(abs.(lons .- target_lon))
ilat = argmin(abs.(lats .- target_lat))
println("\n--- Alice Springs (nearest cell: lon=$(lons[ilon])°, lat=$(lats[ilat])°) ---")

monthly_vars = ["pre", "rd0", "frs", "tmp", "dtr", "reh", "sunp", "wnd"]
for v in monthly_vars
    vals = ds[v][ilon, ilat, :]
    println("  $v: $vals")
end

elv = ds["elv"][ilon, ilat]
println("  elv: $elv m")

# Derived min/max temperature
tmp_vals = Float64.(ds["tmp"][ilon, ilat, :])
dtr_vals = Float64.(ds["dtr"][ilon, ilat, :])
tmin = tmp_vals .- dtr_vals ./ 2
tmax = tmp_vals .+ dtr_vals ./ 2
println("  tmin: $(round.(tmin, digits=1))")
println("  tmax: $(round.(tmax, digits=1))")

close(ds)

# --- Rasters.jl ---
using Rasters

# Open all variables as a RasterStack — inspect to see how dims are named
stack = RasterStack(ncfile)

# Individual variable (all months)
tmp_rast = Raster(ncfile, name = :tmp)
println("\n--- tmp Raster dims ---")
println(dims(tmp_rast))

# Global map of July temperature — index by whatever the month dim is called
# (check println above: likely Ti or Dim{:month})
tmp_jul = tmp_rast[month = At(7)]   # adjust dim name if needed
plot(tmp_jul)

# Point extraction — Alice Springs
point = stack[X(Near(target_lon)), Y(Near(target_lat))]
println("\n--- Alice Springs via Rasters.jl ---")
println(point)
