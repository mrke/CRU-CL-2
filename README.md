# CRU CL 2.0 — Gridded NetCDF Product

A global 10-minute gridded NetCDF of observed mean climate (1961–1990) over land,
derived from the **CRU CL 2.0** dataset.

## Background

CRU CL 2.0 (New et al. 2002) provides monthly mean climate for the global land
surface at 10-minute (~18 km) spatial resolution, based on station observations
from 1961–1990. It supersedes the earlier 0.5-degree CRU CL 1.0 dataset.

The original data are distributed as ASCII files in a bespoke tabular format
that is not directly readable by GDAL or standard raster tools. This repository
converts the originals to a single self-describing CF-compliant NetCDF file
(`cru_cl2.nc`) for use with R, Julia, Python, and any other tool supporting NetCDF.

## Variables

| Variable | Long name                | Units  | Layers |
|----------|--------------------------|--------|--------|
| `elv`    | elevation                | m      | 1      |
| `pre`    | precipitation            | mm     | 12     |
| `rd0`    | wet-day frequency        | days   | 12     |
| `frs`    | frost-day frequency      | days   | 12     |
| `tmp`    | mean temperature         | °C     | 12     |
| `dtr`    | diurnal temperature range| °C     | 12     |
| `reh`    | relative humidity        | %      | 12     |
| `sunp`   | sunshine percentage      | %      | 12     |
| `wnd`    | wind speed               | m s⁻¹  | 12     |

Minimum and maximum temperature can be derived as `tmp ± dtr/2`.

## NetCDF structure

File: `cru_cl2.nc`

### Dimensions

| Dimension | Units         | Values                                      |
|-----------|---------------|---------------------------------------------|
| `lon`     | degrees_east  | −179.917 to 179.917 in 1/6° steps (2160)   |
| `lat`     | degrees_north | −89.917 to 89.917 in 1/6° steps (1080)     |
| `month`   | —             | 1 (January) to 12 (December)               |

The file is CF-1.8 compliant.

## Creating the NetCDF

Run `make_cru_cl2_nc.R` in R with the packages below installed. The script
downloads ~60 MB of compressed ASCII files, rasterises each variable, and writes
`cru_cl2.nc` to the working directory.

```r
install.packages(c("terra", "ncdf4", "R.utils"))
source("make_cru_cl2_nc.R")
```

## Data availability

The pre-built `cru_cl2.nc` (~55 MB, NetCDF4 deflate-compressed) is archived on Zenodo:

> DOI: 10.5281/zenodo.20754689

Download it from Zenodo and place it in the same directory as the R scripts
before running the examples.

## Using the NetCDF

See `cru_cl2_examples.R` for worked examples.

**Example 1 — Global map** of any variable and month:

```r
library(ncdf4); library(terra)
nc <- nc_open("cru_cl2.nc")
tmp_jul <- ncvar_get(nc, "tmp", start = c(1, 1, 7), count = c(-1, -1, 1))
lons <- ncvar_get(nc, "lon"); lats <- ncvar_get(nc, "lat")
r <- rast(t(tmp_jul), extent = c(min(lons), max(lons), min(lats), max(lats)))
crs(r) <- "EPSG:4326"
plot(r)
nc_close(nc)
```

**Example 2 — Point extraction** of all variables at a location:

```r
ilon <- which.min(abs(lons - 144.96))   # Melbourne
ilat <- which.min(abs(lats - (-37.81)))
tmp <- ncvar_get(nc, "tmp", start = c(ilon, ilat, 1), count = c(1, 1, -1))
```

### Julia users

`cru_cl2.nc` can be registered as a Julia
[Artifact](https://pkgdocs.julialang.org/v1/artifacts/) via its Zenodo DOI,
enabling automatic download through
[RasterDataSources.jl](https://github.com/EcoJulia/RasterDataSources.jl).

## Dependencies

| Package | Purpose |
|---------|---------|
| [terra](https://cran.r-project.org/package=terra) | rasterising ASCII data |
| [ncdf4](https://cran.r-project.org/package=ncdf4) | NetCDF read/write |
| [R.utils](https://cran.r-project.org/package=R.utils) | gzip decompression |
| [rnaturalearth](https://cran.r-project.org/package=rnaturalearth) | country boundaries (examples) |
| [rnaturalearthdata](https://cran.r-project.org/package=rnaturalearthdata) | country boundary data (examples) |

## Reference

New, M., Lister, D., Hulme, M. and Makin, I., 2002: A high-resolution data set
of surface climate over global land areas. *Climate Research* **21**: 1–25.

## License

Code in this repository: MIT © Michael Kearney

Data (`cru_cl2.nc`): freely used for non-commercial scientific and educational
purposes, provided it is described as CRU CL 2.0 and attributed to New et al. 2002.
