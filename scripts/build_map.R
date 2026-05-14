# Build the standalone GitHub Pages globe visualisation.

library(sf)
library(dplyr)
library(jsonlite)

project_dir <- normalizePath(
  file.path(getwd(), if (basename(getwd()) == "scripts") ".." else "."),
  winslash = "/",
  mustWork = TRUE
)

data_dir <- file.path(project_dir, "data")

sites <- read.csv(
  file.path(data_dir, "sites.csv"),
  stringsAsFactors = FALSE,
  check.names = FALSE
)

make_id <- function(value) {
  value <- tolower(value)
  value <- gsub("[^a-z0-9]+", "-", value)
  gsub("(^-|-$)", "", value)
}

sites_sf <- st_as_sf(
  sites,
  coords = c("lon", "lat"),
  crs = 4326,
  remove = FALSE
)

anguilla <- st_read(
  file.path(data_dir, "anguilla_boundary.geojson"),
  quiet = TRUE
) |>
  st_transform(4326) |>
  st_make_valid()

map_bbox <- st_bbox(st_union(st_geometry(anguilla), st_geometry(sites_sf)))
center_lon <- mean(c(map_bbox[["xmin"]], map_bbox[["xmax"]]))
center_lat <- mean(c(map_bbox[["ymin"]], map_bbox[["ymax"]]))

anguilla_geojson <- paste(
  readLines(file.path(data_dir, "anguilla_boundary.geojson"), warn = FALSE),
  collapse = "\n"
)

site_features <- sites |>
  rowwise() |>
  mutate(
    feature = list(list(
      type = "Feature",
      geometry = list(
        type = "Point",
        coordinates = list(lon, lat)
      ),
      properties = list(
        id = id,
        country = country,
        site = site,
        setting = setting,
        photo_url = photo_url,
        photo_credit = photo_credit,
        photo_link = photo_link
      )
    ))
  ) |>
  pull(feature)

sites_geojson <- toJSON(
  list(
    type = "FeatureCollection",
    features = site_features
  ),
  auto_unbox = TRUE,
  pretty = TRUE,
  digits = 8
)

poi_sites_json <- sites |>
  transmute(
    id,
    country,
    label = site,
    longitude = lon,
    latitude = lat,
    zoom,
    pitch,
    bearing
  ) |>
  toJSON(
    dataframe = "rows",
    auto_unbox = TRUE,
    pretty = TRUE,
    digits = 8
  )

country_views_json <- sites |>
  group_by(country) |>
  summarise(
    site_count = n(),
    longitude = mean(range(lon)),
    latitude = mean(range(lat)),
    lon_span = diff(range(lon)),
    lat_span = diff(range(lat)),
    .groups = "drop"
  ) |>
  mutate(
    id = make_id(country),
    label = country,
    zoom = case_when(
      site_count == 1 ~ 10.4,
      pmax(lon_span, lat_span) < 0.75 ~ 9.0,
      pmax(lon_span, lat_span) < 5 ~ 5.2,
      TRUE ~ 2.2
    ),
    pitch = if_else(site_count == 1, 45, 52),
    bearing = if_else(country == "Anguilla", -18, -8)
  ) |>
  select(id, label, longitude, latitude, zoom, pitch, bearing, site_count) |>
  toJSON(
    dataframe = "rows",
    auto_unbox = TRUE,
    pretty = TRUE,
    digits = 8
  )

html <- 
'<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Anguilla AMI Sites - Interactive 3D Map</title>
  <link href="https://unpkg.com/maplibre-gl@5.3.0/dist/maplibre-gl.css" rel="stylesheet">
  <script src="https://unpkg.com/maplibre-gl@5.3.0/dist/maplibre-gl.js"></script>
  <style>
    :root {
      color-scheme: dark;
      --ink: #f8fbff;
      --muted: rgba(248, 251, 255, 0.72);
      --line: rgba(255, 255, 255, 0.22);
      --glass: rgba(7, 17, 26, 0.66);
      --gold: #f3c969;
      --reef: #58d6c6;
      --land: #73c36f;
    }

    html, body, #map {
      height: 100%;
      width: 100%;
      margin: 0;
      overflow: hidden;
      background: #07111a;
      font-family: Inter, ui-sans-serif, system-ui, -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
    }

    #map {
      position: absolute;
      inset: 0;
    }

    .hud {
      position: absolute;
      left: 28px;
      top: 24px;
      z-index: 2;
      width: min(390px, calc(100vw - 56px));
      padding: 20px 22px 18px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: linear-gradient(145deg, rgba(8, 22, 34, 0.82), rgba(6, 12, 18, 0.58));
      box-shadow: 0 22px 80px rgba(0, 0, 0, 0.34);
      backdrop-filter: blur(16px);
    }

    .eyebrow {
      margin: 0 0 8px;
      color: var(--reef);
      font-size: 11px;
      font-weight: 800;
      letter-spacing: 0.12em;
      text-transform: uppercase;
    }

    h1 {
      margin: 0;
      color: var(--ink);
      font-size: 30px;
      line-height: 1.03;
      font-weight: 760;
      letter-spacing: 0;
    }

    .hud p {
      margin: 12px 0 0;
      color: var(--muted);
      font-size: 14px;
      line-height: 1.5;
    }

    .site-list {
      display: grid;
      grid-template-columns: 1fr 1fr;
      gap: 8px;
      margin-top: 16px;
    }

    .site-button {
      min-height: 38px;
      border: 1px solid rgba(255, 255, 255, 0.18);
      border-radius: 8px;
      background: rgba(255, 255, 255, 0.07);
      color: var(--ink);
      cursor: pointer;
      font: inherit;
      font-size: 12px;
      font-weight: 700;
      text-align: left;
      padding: 8px 10px;
      transition: transform 160ms ease, background 160ms ease, border-color 160ms ease;
    }

    .site-button:hover {
      background: rgba(88, 214, 198, 0.16);
      border-color: rgba(88, 214, 198, 0.54);
      transform: translateY(-1px);
    }

    .site-button.is-active {
      background: rgba(243, 201, 105, 0.18);
      border-color: rgba(243, 201, 105, 0.7);
      box-shadow: 0 0 22px rgba(243, 201, 105, 0.14);
    }

    .site-detail {
      min-height: 86px;
      margin-top: 16px;
      padding: 14px 15px;
      border: 1px solid rgba(243, 201, 105, 0.2);
      border-radius: 8px;
      background: linear-gradient(145deg, rgba(243, 201, 105, 0.14), rgba(88, 214, 198, 0.08));
      opacity: 0;
      transform: translateY(8px);
      transition: opacity 420ms ease, transform 420ms ease, border-color 420ms ease;
    }

    .site-detail.is-visible {
      opacity: 1;
      transform: translateY(0);
      border-color: rgba(243, 201, 105, 0.5);
    }

    .site-detail-photo {
      width: 100%;
      aspect-ratio: 16 / 9;
      margin-bottom: 12px;
      border-radius: 8px;
      object-fit: cover;
      background: rgba(255, 255, 255, 0.08);
      box-shadow: 0 16px 38px rgba(0, 0, 0, 0.22);
    }

    .site-detail h2 {
      margin: 0;
      color: var(--ink);
      font-size: 18px;
      line-height: 1.15;
      font-weight: 800;
      letter-spacing: 0;
    }

    .site-detail p {
      margin: 8px 0 0;
      color: var(--muted);
      font-size: 13px;
      line-height: 1.45;
    }

    .site-detail-credit {
      display: inline-block;
      margin-top: 9px;
      color: rgba(248, 251, 255, 0.56);
      font-size: 10px;
      line-height: 1.3;
      text-decoration: none;
    }

    .site-detail-credit:hover {
      color: var(--reef);
    }

    .site-flag {
      position: relative;
      width: 0;
      height: 0;
      pointer-events: none;
    }

    .site-flag-body {
      --flag-lift: 72px;
      position: absolute;
      left: 0;
      bottom: 0;
      width: 160px;
      height: 112px;
      opacity: 0;
      transform: translate(-50%, 0) translateY(16px) rotateX(58deg) rotateZ(-2deg);
      transform-origin: 50% 100%;
      transition: opacity 520ms ease, transform 520ms cubic-bezier(0.2, 0.8, 0.2, 1);
      filter: drop-shadow(0 18px 20px rgba(0, 0, 0, 0.28));
    }

    .site-flag.is-visible .site-flag-body {
      opacity: 1;
      transform: translate(-50%, calc(-1 * var(--flag-lift))) translateY(0) rotateX(0deg) rotateZ(-2deg);
    }

    .site-flag-body::before {
      content: "";
      position: absolute;
      left: 78px;
      bottom: 0;
      width: 2px;
      height: 76px;
      background: linear-gradient(to bottom, rgba(255, 255, 255, 0.95), rgba(243, 201, 105, 0.55));
      box-shadow: 0 0 12px rgba(243, 201, 105, 0.55);
    }

    .site-flag-body::after {
      content: "";
      position: absolute;
      left: 73px;
      bottom: -4px;
      width: 12px;
      height: 12px;
      border-radius: 50%;
      background: var(--gold);
      box-shadow: 0 0 22px rgba(243, 201, 105, 0.9);
    }

    .site-flag-card {
      position: absolute;
      left: 82px;
      bottom: 64px;
      min-width: 126px;
      max-width: 160px;
      padding: 8px 10px;
      border: 1px solid rgba(243, 201, 105, 0.55);
      border-radius: 8px;
      background: linear-gradient(145deg, rgba(8, 22, 34, 0.94), rgba(16, 35, 46, 0.78));
      color: var(--ink);
      transform: perspective(420px) rotateY(-12deg);
      backdrop-filter: blur(14px);
    }

    .site-flag-card strong {
      display: block;
      color: var(--ink);
      font-size: 12px;
      line-height: 1.15;
      font-weight: 850;
    }

    .site-flag-card span {
      display: block;
      margin-top: 4px;
      color: var(--muted);
      font-size: 10px;
      line-height: 1.25;
    }

    .legend {
      position: absolute;
      right: 26px;
      bottom: 26px;
      z-index: 2;
      display: flex;
      gap: 10px;
      align-items: center;
      padding: 10px 12px;
      border: 1px solid var(--line);
      border-radius: 8px;
      background: var(--glass);
      color: var(--muted);
      font-size: 12px;
      backdrop-filter: blur(14px);
    }

    .legend span {
      display: inline-block;
      width: 12px;
      height: 12px;
      border: 2px solid var(--gold);
      border-radius: 50%;
      box-shadow: 0 0 18px rgba(243, 201, 105, 0.95);
    }

    .maplibregl-popup-content {
      border: 1px solid rgba(255, 255, 255, 0.2);
      border-radius: 8px;
      background: rgba(6, 14, 22, 0.88);
      color: var(--ink);
      box-shadow: 0 18px 70px rgba(0, 0, 0, 0.4);
      backdrop-filter: blur(14px);
    }

    .popup-title {
      margin: 0 0 4px;
      font-size: 15px;
      font-weight: 800;
      color: var(--ink);
    }

    .popup-body {
      margin: 0;
      font-size: 12px;
      color: var(--muted);
    }

    .maplibregl-popup-tip {
      border-top-color: rgba(6, 14, 22, 0.88) !important;
    }

    @media (max-width: 720px) {
      .hud {
        left: 14px;
        top: 14px;
        width: calc(100vw - 28px);
        box-sizing: border-box;
      }

      h1 {
        font-size: 23px;
      }

      .site-list {
        grid-template-columns: 1fr;
      }

      .legend {
        left: 14px;
        right: auto;
        bottom: 18px;
      }
    }
  </style>
</head>
<body>
  <div id="map"></div>

  <section class="hud" aria-label="Map controls">
    <p class="eyebrow">Anguilla AMI survey</p>
    <h1>Interactive island sites map</h1>
    <p>Choose a country to focus the globe, then select a site to fly in closer. Drag to pan, scroll to zoom, and hold right-click or Ctrl-drag to tilt the view.</p>
    <div class="site-list" id="site-list"></div>
    <article class="site-detail" id="site-detail" aria-live="polite">
      <img class="site-detail-photo" id="site-detail-photo" alt="">
      <h2 id="site-detail-title"></h2>
      <p id="site-detail-setting"></p>
      <a class="site-detail-credit" id="site-detail-credit" href="#" target="_blank" rel="noopener"></a>
    </article>
  </section>

  <div class="legend"><span></span>AMI deployment site</div>

  <script>
    const anguilla = __ANGUILLA_GEOJSON__;
    const sites = __SITES_GEOJSON__;
    const pointsOfInterest = __POI_SITES__;
    const countries = __COUNTRY_VIEWS__;
    const siteLookup = new Map(pointsOfInterest.map((site) => [site.id, site]));
    const siteFeatureLookup = new Map(sites.features.map((feature) => [feature.properties.id, feature]));
    const countryLookup = new Map(countries.map((country) => [country.id, country]));
    const siteCenter = [__CENTER_LON__, __CENTER_LAT__];
    const siteFlags = new Map();
    const globeSpin = {
      enabled: true,
      userInteracting: false,
      flyToInProgress: false,
      maxZoom: 2.7,
      secondsPerRevolution: 220,
      frameId: null,
      lastTimestamp: null
    };

    const map = new maplibregl.Map({
      container: "map",
      center: [0, 18],
      zoom: 1.15,
      pitch: 0,
      bearing: 0,
      antialias: true,
      hash: false,
      style: {
        version: 8,
        glyphs: "https://demotiles.maplibre.org/font/{fontstack}/{range}.pbf",
        sources: {
          osm: {
            type: "raster",
            tiles: [
              "https://a.tile.openstreetmap.org/{z}/{x}/{y}.png",
              "https://b.tile.openstreetmap.org/{z}/{x}/{y}.png",
              "https://c.tile.openstreetmap.org/{z}/{x}/{y}.png"
            ],
            tileSize: 512,
            maxzoom: 10,
            attribution: "&copy; OpenStreetMap contributors"
          }
        },
        layers: [
          {
            id: "satiny-sea",
            type: "background",
            paint: { "background-color": "#07111a" }
          },
          {
            id: "osm-muted",
            type: "raster",
            source: "osm",
            paint: {
              "raster-opacity": 0.34,
              "raster-saturation": -0.72,
              "raster-contrast": 0.18
            }
          }
        ]
      }
    });

    map.addControl(new maplibregl.NavigationControl({ visualizePitch: true }), "top-right");
    map.addControl(new maplibregl.ScaleControl({ maxWidth: 120, unit: "metric" }), "bottom-left");
    renderCountryButtons();
    buildSiteFlags();
    bindInteractionPause();

    map.on("error", (event) => {
      if (event.error) {
        console.warn("MapLibre loading issue:", event.error.message);
      }
    });

    map.on("style.load", () => {
      if (map.setProjection) {
        map.setProjection({ type: "globe" });
      }
      window.setTimeout(startGlobeSpin, 100);
    });

    map.on("load", () => {
      map.addSource("anguilla", { type: "geojson", data: anguilla });
      map.addSource("sites", { type: "geojson", data: sites });

      map.addLayer({
        id: "anguilla-glow",
        type: "line",
        source: "anguilla",
        paint: {
          "line-color": "#58d6c6",
          "line-width": 8,
          "line-blur": 6,
          "line-opacity": 0.45
        }
      });

      map.addLayer({
        id: "anguilla-land",
        type: "fill",
        source: "anguilla",
        paint: {
          "fill-color": "#73c36f",
          "fill-opacity": 0.38
        }
      });

      map.addLayer({
        id: "anguilla-coast",
        type: "line",
        source: "anguilla",
        paint: {
          "line-color": "#f8fbff",
          "line-width": 1.4,
          "line-opacity": 0.72
        }
      });

      map.addLayer({
        id: "site-halo",
        type: "circle",
        source: "sites",
        paint: {
          "circle-radius": [
            "interpolate", ["linear"], ["zoom"],
            8, 8,
            12, 16
          ],
          "circle-color": "#f3c969",
          "circle-opacity": 0.28,
          "circle-blur": 0.55
        }
      });

      map.addLayer({
        id: "site-core",
        type: "circle",
        source: "sites",
        paint: {
          "circle-radius": [
            "interpolate", ["linear"], ["zoom"],
            8, 3.5,
            12, 7
          ],
          "circle-color": "#f3c969",
          "circle-stroke-color": "#07111a",
          "circle-stroke-width": 1.5
        }
      });

      map.addLayer({
        id: "site-labels",
        type: "symbol",
        source: "sites",
        layout: {
          "text-field": ["get", "site"],
          "text-font": ["Open Sans Bold"],
          "text-size": [
            "interpolate", ["linear"], ["zoom"],
            8, 14,
            12, 21
          ],
          "text-anchor": "top",
          "text-offset": [0, 1.2],
          "text-allow-overlap": true,
          "text-ignore-placement": true
        },
        paint: {
          "text-color": "#f8fbff",
          "text-halo-color": "#07111a",
          "text-halo-width": 2.2,
          "text-halo-blur": 0.7
        }
      });

      map.on("click", "site-core", showPopup);
      map.on("click", "site-labels", showPopup);
      map.on("mouseenter", "site-core", () => map.getCanvas().style.cursor = "pointer");
      map.on("mouseleave", "site-core", () => map.getCanvas().style.cursor = "");

      pulseSites();
      window.setTimeout(startGlobeSpin, 250);
      map.once("idle", startGlobeSpin);
    });

    function showPopup(event) {
      const feature = event.features[0];
      const coordinates = feature.geometry.coordinates.slice();
      const name = feature.properties.site;
      const setting = feature.properties.setting;

      renderSiteButtons(feature.properties.country);
      flyToSite(feature.properties.id);

      new maplibregl.Popup({ offset: 18, closeButton: false })
        .setLngLat(coordinates)
        .setHTML(`<p class="popup-title">${name}</p><p class="popup-body">${setting}</p>`)
        .addTo(map);
    }

    function updateSiteDetail(feature) {
      const detail = document.getElementById("site-detail");
      const photo = document.getElementById("site-detail-photo");
      const title = document.getElementById("site-detail-title");
      const setting = document.getElementById("site-detail-setting");
      const credit = document.getElementById("site-detail-credit");
      const siteName = feature.properties.site;

      detail.classList.remove("is-visible");

      window.setTimeout(() => {
        photo.src = feature.properties.photo_url;
        photo.alt = `${siteName} thumbnail image`;
        title.textContent = siteName;
        setting.textContent = feature.properties.setting;
        credit.textContent = feature.properties.photo_credit;
        credit.href = feature.properties.photo_link;
        detail.classList.add("is-visible");
      }, 90);

      document.querySelectorAll(".site-button").forEach((button) => {
        button.classList.toggle("is-active", button.dataset.site === feature.properties.id);
      });
    }

    function buildSiteFlags() {
      sites.features.forEach((feature) => {
        const element = document.createElement("div");
        element.className = "site-flag";
        element.innerHTML = `
          <div class="site-flag-body">
            <div class="site-flag-card">
              <strong>${feature.properties.site}</strong>
              <span>${feature.properties.setting}</span>
            </div>
          </div>
        `;

        const marker = new maplibregl.Marker({
          element,
          anchor: "center",
          offset: [0, -6],
          pitchAlignment: "viewport",
          rotationAlignment: "viewport"
        })
          .setLngLat(feature.geometry.coordinates)
          .addTo(map);

        siteFlags.set(feature.properties.site, { marker, element });
      });
    }

    function showSiteFlag(feature) {
      const siteName = feature.properties.site;

      siteFlags.forEach(({ element }, name) => {
        element.classList.toggle("is-visible", name === siteName);
      });
    }

    function clearSiteDetail() {
      const detail = document.getElementById("site-detail");
      detail.classList.remove("is-visible");
      siteFlags.forEach(({ element }) => {
        element.classList.remove("is-visible");
      });
    }

    function createHudButton(label, onClick, options = {}) {
      const button = document.createElement("button");
      button.className = "site-button";
      button.type = "button";
      button.textContent = label;

      if (options.siteId) {
        button.dataset.site = options.siteId;
      }

      if (options.countryId) {
        button.dataset.country = options.countryId;
      }

      button.addEventListener("click", onClick);
      return button;
    }

    function renderCountryButtons() {
      const list = document.getElementById("site-list");
      list.replaceChildren();
      clearSiteDetail();

      countries.forEach((country) => {
        const label = `${country.label} (${country.site_count})`;
        list.appendChild(createHudButton(label, () => {
          flyToCountry(country.id);
        }, { countryId: country.id }));
      });
    }

    function renderSiteButtons(countryName) {
      const list = document.getElementById("site-list");
      list.replaceChildren();

      list.appendChild(createHudButton("All countries", renderCountryButtons));

      pointsOfInterest
        .filter((site) => site.country === countryName)
        .forEach((site) => {
          list.appendChild(createHudButton(site.label, () => {
          flyToSite(site.id);
        }, { siteId: site.id }));
        });
    }

    function flyToCountry(countryId) {
      const country = countryLookup.get(countryId);

      if (!country) {
        return;
      }

      globeSpin.enabled = false;
      globeSpin.flyToInProgress = true;
      clearSiteDetail();
      renderSiteButtons(country.label);

      map.flyTo({
        center: [country.longitude, country.latitude],
        zoom: country.zoom,
        pitch: country.pitch,
        bearing: country.bearing,
        speed: 0.72,
        curve: 1.55,
        essential: true
      });
    }

    function flyToSite(siteId) {
      const site = siteLookup.get(siteId);
      const feature = siteFeatureLookup.get(siteId);

      if (!site || !feature) {
        return;
      }

      globeSpin.enabled = false;
      globeSpin.flyToInProgress = true;
      updateSiteDetail(feature);
      showSiteFlag(feature);

      map.flyTo({
        center: [site.longitude, site.latitude],
        zoom: site.zoom,
        pitch: site.pitch,
        bearing: site.bearing,
        speed: 0.72,
        curve: 1.55,
        essential: true
      });
    }

    function bindInteractionPause() {
      const pauseForUser = () => {
        if (globeSpin.flyToInProgress) {
          return;
        }
        globeSpin.enabled = false;
        globeSpin.userInteracting = true;
        stopGlobeSpin();
      };

      ["mousedown", "touchstart", "wheel", "dragstart", "pitchstart", "rotatestart", "zoomstart"].forEach((eventName) => {
        map.on(eventName, pauseForUser);
      });
      map.getCanvas().addEventListener("pointerdown", pauseForUser, { passive: true });

      map.on("moveend", () => {
        globeSpin.userInteracting = false;
        globeSpin.flyToInProgress = false;
      });
    }

    function startGlobeSpin() {
      if (globeSpin.frameId !== null) {
        return;
      }

      globeSpin.lastTimestamp = null;
      globeSpin.frameId = requestAnimationFrame(spinFrame);
    }

    function stopGlobeSpin() {
      if (globeSpin.frameId !== null) {
        cancelAnimationFrame(globeSpin.frameId);
      }
      globeSpin.frameId = null;
      globeSpin.lastTimestamp = null;
    }

    function spinFrame(timestamp) {
      if (!globeSpin.enabled || globeSpin.userInteracting || map.getZoom() >= globeSpin.maxZoom) {
        stopGlobeSpin();
        return;
      }

      if (globeSpin.lastTimestamp === null) {
        globeSpin.lastTimestamp = timestamp;
      }

      const elapsedSeconds = (timestamp - globeSpin.lastTimestamp) / 1000;
      const center = map.getCenter();
      const degreesPerSecond = 360 / globeSpin.secondsPerRevolution;
      const nextLongitude = center.lng - degreesPerSecond * elapsedSeconds;

      // Direct camera nudging avoids relying on chained map animation events during initial globe setup.
      map.setCenter([nextLongitude, center.lat]);
      globeSpin.lastTimestamp = timestamp;
      globeSpin.frameId = requestAnimationFrame(spinFrame);
    }

    function pulseSites() {
      let start = null;

      function frame(timestamp) {
        if (!start) start = timestamp;
        const progress = ((timestamp - start) % 1800) / 1800;
        const radius = 9 + Math.sin(progress * Math.PI) * 8;
        const opacity = 0.16 + Math.sin(progress * Math.PI) * 0.2;

        if (map.getLayer("site-halo")) {
          map.setPaintProperty("site-halo", "circle-radius", radius);
          map.setPaintProperty("site-halo", "circle-opacity", opacity);
        }

        requestAnimationFrame(frame);
      }

      requestAnimationFrame(frame);
    }
  </script>
</body>
</html>'

html <- gsub("__ANGUILLA_GEOJSON__", anguilla_geojson, html, fixed = TRUE)
html <- gsub("__SITES_GEOJSON__", sites_geojson, html, fixed = TRUE)
html <- gsub("__POI_SITES__", poi_sites_json, html, fixed = TRUE)
html <- gsub("__COUNTRY_VIEWS__", country_views_json, html, fixed = TRUE)
html <- gsub("__CENTER_LON__", sprintf("%.8f", center_lon), html, fixed = TRUE)
html <- gsub("__CENTER_LAT__", sprintf("%.8f", center_lat), html, fixed = TRUE)

output_file <- file.path(project_dir, "index.html")
writeLines(html, output_file, useBytes = TRUE)

message("Wrote interactive globe site: ", output_file)
