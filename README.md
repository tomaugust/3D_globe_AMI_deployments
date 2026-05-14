# Anguilla AMI 3D Globe

Interactive WebGL globe visualisation for Anguilla AMI deployment sites.

## Files

- `index.html` is the static site entry point for GitHub Pages.
- `scripts/build_map.R` rebuilds `index.html` from the data files.
- `data/sites.csv` stores editable points of interest and camera settings.
- `data/anguilla_boundary.geojson` stores the Anguilla boundary layer.

## Rebuild

Run from the project root:

```powershell
Rscript .\scripts\build_map.R
```

## GitHub Pages

Configure Pages to deploy from the `main` branch root directory. The root `index.html` is the published page.
