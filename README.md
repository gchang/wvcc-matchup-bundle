# WVCC CrIS/VIIRS matchup bundle

The MEaSUREs WVCC (Water Vapor and Cloud Climate) CrIS/VIIRS 750-m matchup indexes tell, for every CrIS sounder field of view, which VIIRS imager pixels fall inside it (Wang et al. 2016 method). GES DISC distributes them as `SNPP_CrIS_VIIRS750m_IND` (DOI 10.5067/MEASURES/WVCC/DATA211) and `J1_CrIS_VIIRS750m_IND` (DOI 10.5067/MEASURES/WVCC/DATA212). The code is split across two JPL-WVCC repositories: the production runner and the collocation library. This repository holds them side by side as git submodules, pinned to the commits that were checked, so the whole algorithm can be cloned in one step:

```sh
git clone --recurse-submodules https://github.com/gchang/wvcc-matchup-bundle.git
```

| Submodule | Repository | Commit | Role |
|---|---|---|---|
| `matchup_pge` | https://github.com/JPL-WVCC/matchup_pge (unchanged) | 77def16ce19e82a52bd4fce2b39348c01d315f07 | the production runner, `matchup/parallel_run_matchup.py` |
| `CrIS_VIIRS_collocation-master` | https://github.com/gchang/wvcc-cris-viirs-collocation, a copy of https://github.com/JPL-WVCC/CrIS_VIIRS_collocation-master at 77f84fe4e79a7308e3995dc5a69d0e53d60898ac | a9cff3fb0c85093ff218788372a836bc4febf307 | the collocation library (`code_test_QY.py`, `geo_QY.py`) |

The collocation library is a copy with two small fixes in `geo_QY.py` so it runs on numpy 1.24 and newer, including numpy 2; the upstream commit needs numpy 1.23 or older. The fixes do not change the product. Its `MAAP_CHANGES.md` lists them. `matchup_pge` is used as is.

Neither upstream repository has a license file. Each submodule keeps its own terms and attribution; this repository adds only the README, `environment.yml` and `bundle_env.sh`.

This bundle documents the CrIS/VIIRS runner. `matchup_pge` also holds an AIRS/MODIS runner (`airs_modis_parallel_run_matchup.py`), which needs a different library (JPL-WVCC/AIRS_MODIS_collocation-master) and is not covered here.

## Software

Python with numpy, netCDF4 and pykdtree. `environment.yml` holds the checked conda-forge set:

```sh
conda env create -f environment.yml
conda activate wvcc-matchup-bundle
```

The runner finds the library through `sys.path`. `matchup_pge`'s README says to edit the hard-coded `sys.path.append` line in `parallel_run_matchup.py`; `bundle_env.sh` puts the library on `PYTHONPATH` instead, so the submodule stays untouched:

```sh
source bundle_env.sh    # from the bundle root
```

## Input data

All inputs need an Earthdata Login (for example in `~/.netrc`). For one CrIS granule:

- **CrIS L1B**: one NASA CrIS L1B file. For NOAA-20 (J1) this is collection `SNDRJ1CrISL1B` version 3 at GES DISC (version 3 is required); for SNPP it is `SNPPCrISL1B` (production used version 2; the SNPP path was not checked here), with `--sp SNPP`. Each file is about 220 MB.
  - Example: https://data.gesdisc.earthdata.nasa.gov/data/JPSS1_Sounder_Level1/SNDRJ1CrISL1B.3/2025/365/SNDR.J1.CRIS.20251231T1936.m06.g197.L1B.std.v03_08.G.260101021810.nc
- **VIIRS geolocation**: the VIIRS 750-m geolocation granules that cover the CrIS granule's 6 minutes, from LAADS DAAC: `VJ103MOD` (collection 5201) for J1, `VNP03MOD` (collection 5110) for SNPP. Each is 45 to 60 MB. The runner reads the start and end time of every file it finds and keeps the ones that overlap, so extra files do no harm.
  - Example, the five J1 granules from 19:24 to 19:48 UTC on 2025-12-31 (the runner picks 19:30, 19:36 and 19:42): `https://data.laadsdaac.earthdatacloud.nasa.gov/prod-lads/VJ103MOD/VJ103MOD.A2025365.1924.021.2026001005032.nc`, and in the same folder `VJ103MOD.A2025365.1930.021.2026001005036.nc`, `VJ103MOD.A2025365.1936.021.2026001005034.nc`, `VJ103MOD.A2025365.1942.021.2026001005034.nc` and `VJ103MOD.A2025365.1948.021.2026001004031.nc`.

For example, with curl and `~/.netrc`: `curl -n -L -c cookies -b cookies -O <url>`.

The runner finds the files only in this layout, under the folders given by `--cr` and `--vr`:

```
cris/YYYY/MM/DD/crisl1b/SNDR.J1.CRIS.*L1B.std*.nc     (SNDR.SNPP.CRIS.* for SNPP)
viirs/YYYY/DDD/VJ103MOD.*.nc                           (VNP03MOD.* for SNPP; DDD is the day of year)
```

The runner works by day: it processes every CrIS file in a day folder, one process per file (up to `--c` at a time), and looks for VIIRS files in the day folders before, of and after that day.

## Running one granule

From the bundle root, with the inputs in `matchup_pge/matchup/cris/` and `matchup_pge/matchup/viirs/` in the layout above:

```sh
source bundle_env.sh
cd matchup_pge/matchup
python parallel_run_matchup.py --y 2025 --m 12 --d1 31 --d2 31 --sp J1 --pr out/ --cr cris/ --vr viirs/ --c 2
```

The three folders are relative to the working directory (`matchup_pge/matchup`); absolute folders work too. Each must end in `/`, because the runner joins paths by plain string concatenation. Always give `--c`, `--cr`, `--vr` and `--pr`: without `--c` the runner stops with a TypeError, and without the folder options it falls back to paths on the JPL production machines. The runner also writes `cris_viirs_log.log` into the working directory.

The product goes to `out/2025/12/31/<CrIS file name without .nc>/`: `manifest.mf` and the folder `IND_CrIS_VIIRSMOD_SNDR.J1.20251231T1936.g197/` with the NetCDF product (`.nc`, about 1.2 MB) and two GES DISC ingest files (`.dataset.json`, `.met.json`).

Things to know:

- **Check that the product exists.** The runner does not check the exit codes of its worker processes, so it exits 0 even when a granule fails, leaving an empty folder.
- **Two variable names are swapped**, here and in the official GES DISC files alike: `number_of_pixels` holds the VIIRS along-track line in the stacked granules and `number_of_lines` holds the cross-track pixel.
- **Year boundaries.** The neighboring VIIRS day folders are looked up under the CrIS year, so for granules on December 31 and January 1 the files from the other year are never read. Only footprints at the very edge of the time window could be affected; the check below is on December 31 and matches the official product.
- One granule needs about 3.9 GB of memory per process, so memory grows with `--c`.

Checked on 2026-10-25 from a fresh `git clone --recurse-submodules`, in a conda env built from `environment.yml` (Python 3.12, numpy 2.5.4), with the command above and the example inputs, and no network during the run: the product is identical to the official GES DISC granule `IND_CrIS_VIIRSMOD_SNDR.J1.20251231T1936.g197.nc` (`J1_CrIS_VIIRS750m_IND` V1, https://data.gesdisc.earthdata.nasa.gov/data/AIRS_CloudSat/J1_CrIS_VIIRS750m_IND.1/2025/365/IND_CrIS_VIIRSMOD_SNDR.J1.20251231T1936.g197.nc). All 12,150 per-footprint pixel counts, all 5,605,455 VIIRS line and pixel indexes, and every global attribute except `PRODUCTIONDATE` are the same. The run took 13 s and 3.9 GB.
