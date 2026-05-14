# Anguilla AMI 3D Globe

Interactive 3D globe visualisation for Anguilla AMI deployment sites.

The project is designed as a small, static GitHub Pages site. The published
page is `index.html`, which is generated from the editable data files in
`data/` by `scripts/build_map.R`.

## What It Shows

The map opens as a slowly rotating globe and highlights Anguilla and the AMI
deployment locations. Users can:

- drag, zoom, rotate, and pitch the MapLibre globe;
- use the site buttons to fly to a deployment location;
- click deployment markers or labels to open a popup;
- view a short site description and credited image for each deployment site.

Current deployment sites are:

- Fountain reserve
- Prickly Pear Cay
- Dog Island
- Sombrero Island

## Project Structure

```text
.
|-- index.html
|-- README.md
|-- data/
|   `-- sites.csv
|-- scripts/
|   `-- build_map.R
`-- .github/
    `-- workflows/
        `-- pages.yml
```

## Key Files

`index.html`

The standalone web page served by GitHub Pages. It contains the MapLibre setup,
CSS, embedded site data, and all browser interaction code.

`scripts/build_map.R`

The source build script. It reads `data/sites.csv`, converts the site table to
GeoJSON, inserts the generated JSON into the HTML template, and writes a fresh
`index.html`.

`data/sites.csv`

The editable list of deployment locations, camera settings, descriptions, and
image credits.

`.github/workflows/pages.yml`

GitHub Actions workflow that deploys the repository root to GitHub Pages after
pushes to `main`.

## Data Schema

`data/sites.csv` has one row per deployment site.

| Column | Purpose |
| --- | --- |
| `id` | Stable machine-readable site identifier. Keep this unique. |
| `country` | Country grouping used for the first-level HUD buttons. |
| `site` | Display name used in buttons, labels, popups, and detail panel. |
| `lon` | Site longitude in WGS84 decimal degrees. |
| `lat` | Site latitude in WGS84 decimal degrees. |
| `zoom` | Map zoom level used when flying to the site. |
| `pitch` | Camera pitch used when flying to the site. |
| `bearing` | Camera bearing used when flying to the site. |
| `setting` | Short descriptive text shown in the popup and detail panel. |
| `photo_url` | Image URL shown in the detail panel. |
| `photo_credit` | Credit line for the image. |
| `photo_link` | Link target for the image credit. |

## Editing Site Content

To add or change deployment locations:

1. Edit `data/sites.csv`.
2. Keep `id` values unique and URL-safe, for example `new-site-name`.
3. Set `country` to the country-level group that should appear in the first HUD
   menu, for example `Anguilla` or `United Kingdom`.
4. Use decimal longitude and latitude in EPSG:4326 / WGS84.
5. Adjust `zoom`, `pitch`, and `bearing` so the fly-to camera frames the site
   well.
6. Rebuild `index.html` with the command below.
7. Open `index.html` locally to check the result before committing.

## Rebuilding The Site

Run from the repository root:

```powershell
Rscript .\scripts\build_map.R
```

Or, if R is not on your `PATH`, use the full Rscript path, for example:

```powershell
& 'C:\Program Files\R\R-4.6.0\bin\Rscript.exe' .\scripts\build_map.R
```

The script requires these R packages:

- `sf`
- `dplyr`
- `jsonlite`

If any are missing, install them in R:

```r
install.packages(c("sf", "dplyr", "jsonlite"))
```

## Local Preview

Because the site is a single static HTML file, you can usually preview it by
opening `index.html` in a browser. A local web server is also fine if you prefer
to test it over HTTP:

```powershell
python -m http.server 8000
```

Then open:

```text
http://localhost:8000/
```

The page loads MapLibre, OpenStreetMap tiles, glyphs, and site images from
external URLs, so it needs an internet connection for the full visual experience.

## GitHub Pages Deployment

This repository includes a GitHub Actions Pages workflow in
`.github/workflows/pages.yml`.

To deploy:

1. Push the repository to GitHub.
2. In the GitHub repository, go to **Settings > Pages**.
3. Set the source to **GitHub Actions**.
4. Push to `main`.
5. The workflow will upload the repository root and publish `index.html`.

For the intended repository:

```powershell
git remote add origin https://github.com/tomaugust/3D_globe_AMI_deployments.git
git push -u origin main
```

Once Pages has deployed, the site should be available at:

```text
https://tomaugust.github.io/3D_globe_AMI_deployments/
```

If the workflow fails at `Configure Pages` with `Get Pages site failed` or
`HttpError: Not Found`, the repository has not yet been enabled as a GitHub
Pages site. Open **Settings > Pages** in the GitHub repository and set the build
and deployment source to **GitHub Actions**, then re-run the workflow.

## Implementation Notes

- The browser map uses MapLibre GL JS 5.3.0 from the unpkg CDN.
- The map style uses OpenStreetMap raster tiles with subdued styling.
- Globe projection is enabled with `map.setProjection({ type: "globe" })` when
  supported by the loaded MapLibre version.
- The site GeoJSON is embedded directly in `index.html` by the R build script.
  This keeps GitHub Pages deployment simple because there is no runtime data
  fetch.
- The initial globe rotation stops when the user interacts with the map or when
  the map zooms in beyond the configured spin threshold.
- The site detail panel uses externally hosted, credited images. If an external
  image URL changes or becomes unavailable, update the relevant row in
  `data/sites.csv` and rebuild.

## Maintenance Checklist

Before pushing changes:

1. Update `data/sites.csv` as needed.
2. Run `Rscript .\scripts\build_map.R`.
3. Confirm `index.html` changed as expected.
4. Preview the site locally.
5. Commit both the source data/script changes and the regenerated `index.html`.
6. Push to `main` and check the GitHub Pages workflow.

## Review Notes

The codebase is intentionally compact and suitable for GitHub Pages. The main
maintenance point is that `index.html` is generated output, while
`scripts/build_map.R` and `data/` are the source of truth. For durable edits,
change the data or build script first, then regenerate the HTML.

Two external dependencies are loaded at runtime:

- MapLibre GL JS and CSS from unpkg
- OpenStreetMap raster tiles and remote image URLs

If the visualisation needs to work offline or in a locked-down network
environment, those assets would need to be vendored or replaced with locally
hosted equivalents.
