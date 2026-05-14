# AMI 3D Globe

A static, interactive 3D globe for exploring insect monitoring stations around
the world. The visualisation is designed for GitHub Pages and is built as a
generated `index.html` page with local CSS and JavaScript assets.

The editable source of truth is:

- `data/sites.csv` for site records, map positions, metrics, and image paths
- `data/about.json` for About modal copy and links
- `data/images/` for local site photographs and gallery images
- `templates/index.html` for page structure
- `assets/styles.css` and `assets/app.js` for browser styling and behaviour
- `scripts/build_map.R` for validation, generated map data, and template rendering

## User Experience

The page opens on a slowly rotating world view with a floating title:

```text
Be Inspired
Explore insect monitoring stations around the world
```

The interface then lets users:

- choose a country from the control panel;
- fly the globe camera to that country;
- see all site name flags for the selected country;
- choose a specific monitoring station;
- view station metrics, a local site photograph, description, and image credit;
- open a centered image carousel for that site's gallery;
- cycle gallery images with arrow buttons or keyboard left/right keys;
- return to the world view.

The current site data includes monitoring stations grouped under:

- Anguilla
- Costa Rica
- Japan
- Thailand
- United Kingdom

## File Structure

```text
.
|-- index.html
|-- README.md
|-- assets/
|   |-- app.js
|   `-- styles.css
|-- data/
|   |-- about.json
|   |-- sites.csv
|   `-- images/
|       `-- <country-slug>/
|           `-- <site-slug>/
|               |-- photo.jpg
|               `-- gallery/
|                   |-- moth-01.png
|                   |-- moth-02.png
|                   |-- moth-03.png
|                   `-- captions.csv
|-- scripts/
|   `-- build_map.R
|-- templates/
|   `-- index.html
`-- .github/
    `-- workflows/
        `-- pages.yml
```

## Core Files

`index.html`

The generated static site served by GitHub Pages. It includes the page markup,
embedded GeoJSON/site data, and links to the local CSS and JavaScript assets.
Do not edit this by hand for durable changes; regenerate it from
`scripts/build_map.R`.

`scripts/build_map.R`

Builds the site. It validates site IDs and local asset paths, reads
`data/sites.csv` and `data/about.json`, discovers each site's gallery image
paths and captions, creates the GeoJSON and country camera data, injects
everything into the HTML template, and writes `index.html`.

`templates/index.html`

Editable page structure with placeholders for generated data and About content.

`assets/styles.css`

Editable site styles loaded by `index.html`.

`assets/app.js`

Editable browser-side MapLibre and UI interaction code loaded by `index.html`.

`data/sites.csv`

The editable site table. Each row represents one monitoring station.

`data/about.json`

Editable About modal title, body copy, and link cards.

`data/images/`

Local image assets used by the generated site. Each station has a primary
`photo.jpg` and a `gallery/` directory. The current gallery contents are
temporary generated moth-on-backboard images with editable captions stored in
each gallery's `captions.csv`.

`.github/workflows/pages.yml`

GitHub Actions workflow for publishing the repository root to GitHub Pages.

## Data Schema

`data/sites.csv` contains one row per monitoring station.

| Column | Description |
| --- | --- |
| `id` | Unique URL-safe site identifier, for example `fountain-reserve`. |
| `country` | Country grouping used for the first-level buttons. |
| `site` | Display name used in buttons, labels, popups, and detail panels. |
| `lon` | Longitude in WGS84 decimal degrees. |
| `lat` | Latitude in WGS84 decimal degrees. |
| `zoom` | Map zoom used when flying to the site. |
| `pitch` | Camera pitch used when flying to the site. |
| `bearing` | Camera bearing used when flying to the site. |
| `number_of_nights` | Station metric shown in the detail panel. |
| `number_of_images` | Station metric shown in the detail panel. |
| `number_of_detections` | Station metric shown in the detail panel. |
| `setting` | Short site description shown in popups and detail panels. |
| `photo_url` | Local path to the primary site image. |
| `photo_credit` | Image credit shown in the detail panel. |
| `photo_link` | URL opened from the image credit link. |

## Image Assets

Primary site images and gallery images are local project files. Use lower-case,
URL-safe folder slugs that match the country and site naming pattern.

Expected structure for a site:

```text
data/images/<country-slug>/<site-slug>/
|-- photo.jpg
`-- gallery/
    |-- image-01.jpg
    |-- image-02.jpg
    |-- image-03.jpg
    `-- captions.csv
```

The gallery may contain `.jpg`, `.jpeg`, `.png`, or `.webp` files. During the
build, `scripts/build_map.R` scans each site's `gallery/` folder and embeds the
sorted image paths in `index.html`.

Each gallery should also include `captions.csv` with this schema:

| Column | Description |
| --- | --- |
| `image` | File name of the gallery image, for example `moth-01.png`. |
| `caption` | Caption text for that image. |

Example:

```csv
image,caption
"moth-01.png","Large silk moth on monitoring board"
"moth-02.png","Mixed moth assemblage on white backboard"
```

The placeholder galleries currently use:

```text
moth-01.png
moth-02.png
moth-03.png
```

## Editing Content

To edit an existing site:

1. Update the relevant row in `data/sites.csv`.
2. Replace or add files under that site's `data/images/<country>/<site>/`
   folder if needed.
3. Run the build script.
4. Preview `index.html`.
5. Commit the source data/assets and the regenerated `index.html` together.

To add a new site:

1. Add a row to `data/sites.csv` with a unique `id`.
2. Create `data/images/<country-slug>/<site-slug>/photo.jpg`.
3. Create `data/images/<country-slug>/<site-slug>/gallery/`.
4. Add gallery images to that folder.
5. Add `captions.csv` to the gallery folder.
6. Set `photo_url` in `data/sites.csv` to the local `photo.jpg` path.
7. Tune `zoom`, `pitch`, and `bearing` for the site camera.
8. Rebuild and preview.

## Building

Run from the repository root:

```powershell
Rscript .\scripts\build_map.R
```

If `Rscript` is not on `PATH`, use the full Windows path:

```powershell
& 'C:\Program Files\R\R-4.6.0\bin\Rscript.exe' .\scripts\build_map.R
```

Required R packages:

- `sf`
- `dplyr`
- `jsonlite`

Install missing packages in R:

```r
install.packages(c("sf", "dplyr", "jsonlite"))
```

The build fails early if site IDs are duplicated, primary photos are missing,
gallery captions do not match gallery image files, or gallery caption files have
the wrong schema.

## Local Preview

For a quick check, open `index.html` directly in a browser.

For an HTTP preview, run:

```powershell
python -m http.server 8000
```

Then open:

```text
http://localhost:8000/
```

The page uses local site images, but still loads MapLibre, fonts, glyphs, and
OpenStreetMap tiles from external URLs.

## Deployment

The site is deployed through GitHub Pages using the workflow at
`.github/workflows/pages.yml`.

Deployment flow:

1. Rebuild `index.html`.
2. Commit the source files, local assets, and generated HTML.
3. Push to `main`.
4. GitHub Actions publishes the repository root to Pages.

The configured remote is:

```text
https://github.com/tomaugust/3D_globe_AMI_deployments.git
```

The published site is expected at:

```text
https://tomaugust.github.io/3D_globe_AMI_deployments/
```

In the GitHub repository settings, Pages should be configured to use
**GitHub Actions** as the build and deployment source.

## Runtime Dependencies

Runtime assets loaded from CDNs or external services:

- MapLibre GL JS and CSS from unpkg
- MapLibre glyphs from `demotiles.maplibre.org`
- OpenStreetMap raster tiles
- Google Fonts for the world-view script title

Runtime assets loaded locally from the repository:

- CSS and JavaScript under `assets/`
- site detail photographs under `data/images/`
- gallery carousel images under each site's `gallery/` folder
- embedded site and country data generated into `index.html`

## Maintenance Notes

`index.html` is generated output. Durable changes should be made in
`templates/`, `assets/`, `scripts/build_map.R`, `data/sites.csv`,
`data/about.json`, or `data/images/`, then rebuilt.

Before pushing:

1. Run `Rscript .\scripts\build_map.R`.
2. Preview the site.
3. Check `git status` includes the intended source, asset, and generated HTML
   changes.
4. Commit and push to `main`.
