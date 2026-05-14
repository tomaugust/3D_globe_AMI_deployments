const { sites, pointsOfInterest, countries, siteCenter } = window.AMI_GLOBE_DATA;
const siteLookup = new Map(pointsOfInterest.map((site) => [site.id, site]));
const siteFeatureLookup = new Map(sites.features.map((feature) => [feature.properties.id, feature]));
const countryLookup = new Map(countries.map((country) => [country.id, country]));
const siteFlags = new Map();
let activeSiteId = null;
let activeSiteFeature = null;
let activeGalleryItems = [];
let activeGalleryIndex = 0;
let siteFlightId = 0;
const globalView = {
  center: [0, 18],
  zoom: 1.15,
  pitch: 0,
  bearing: 0
};
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
  center: globalView.center,
  zoom: globalView.zoom,
  pitch: globalView.pitch,
  bearing: globalView.bearing,
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
        maxzoom: 19,
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
          "raster-opacity": 0.62,
          "raster-saturation": -0.35,
          "raster-contrast": 0.08,
          "raster-brightness-min": 0.08,
          "raster-brightness-max": 0.92
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
  map.addSource("sites", { type: "geojson", data: sites });

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

  const popupContent = document.createElement("div");
  const popupTitle = document.createElement("p");
  const popupBody = document.createElement("p");

  popupTitle.className = "popup-title";
  popupTitle.textContent = name;
  popupBody.className = "popup-body";
  popupBody.textContent = setting;
  popupContent.append(popupTitle, popupBody);

  new maplibregl.Popup({ offset: 18, closeButton: false })
    .setLngLat(coordinates)
    .setDOMContent(popupContent)
    .addTo(map);
}

function updateSiteDetail(feature) {
  const detail = document.getElementById("site-detail");
  const photo = document.getElementById("site-detail-photo");
  const title = document.getElementById("site-detail-title");
  const setting = document.getElementById("site-detail-setting");
  const credit = document.getElementById("site-detail-credit");
  const nights = document.getElementById("site-stat-nights");
  const images = document.getElementById("site-stat-images");
  const detections = document.getElementById("site-stat-detections");
  const siteId = feature.properties.id;
  const siteName = feature.properties.site;

  detail.classList.remove("is-visible");

  window.setTimeout(() => {
    if (activeSiteId !== siteId) {
      return;
    }

    nights.textContent = formatMetric(feature.properties.number_of_nights);
    images.textContent = formatMetric(feature.properties.number_of_images);
    detections.textContent = formatMetric(feature.properties.number_of_detections);
    photo.src = feature.properties.photo_url;
    photo.alt = `${siteName} thumbnail image`;
    title.textContent = siteName;
    setting.textContent = feature.properties.setting;
    credit.textContent = feature.properties.photo_credit;
    credit.href = feature.properties.photo_link;
    detail.classList.add("is-visible");
  }, 90);

  document.querySelectorAll(".site-button").forEach((button) => {
    button.classList.toggle("is-active", button.dataset.site === siteId);
  });
}

function showGalleryTrigger(feature) {
  if (activeSiteId !== feature.properties.id) {
    return;
  }

  const trigger = document.getElementById("gallery-trigger");
  const hasGallery = Array.isArray(feature.properties.gallery_items) && feature.properties.gallery_items.length > 0;
  activeSiteFeature = feature;
  trigger.classList.toggle("is-visible", hasGallery);
}

function hideGalleryTrigger() {
  document.getElementById("gallery-trigger").classList.remove("is-visible");
  closeGallery();
}

function clearActiveSiteGallery() {
  activeSiteId = null;
  activeSiteFeature = null;
  siteFlightId += 1;
  hideGalleryTrigger();
}

function openGallery() {
  if (!activeSiteFeature) {
    return;
  }

  const items = activeSiteFeature.properties.gallery_items || [];
  if (!items.length) {
    return;
  }

  const overlay = document.getElementById("gallery-overlay");
  const title = document.getElementById("gallery-title");

  title.textContent = `${activeSiteFeature.properties.site} gallery`;
  activeGalleryItems = items;
  activeGalleryIndex = 0;
  renderGalleryImage();

  overlay.classList.add("is-visible");
}

function closeGallery() {
  const overlay = document.getElementById("gallery-overlay");
  if (overlay) {
    overlay.classList.remove("is-visible");
  }
}

function openAbout() {
  document.getElementById("about-overlay").classList.add("is-visible");
}

function closeAbout() {
  document.getElementById("about-overlay").classList.remove("is-visible");
}

function showWorldTitle() {
  document.getElementById("world-title").classList.add("is-visible");
}

function hideWorldTitle() {
  document.getElementById("world-title").classList.remove("is-visible");
}

function renderGalleryImage() {
  const image = document.getElementById("gallery-image");
  const caption = document.getElementById("gallery-caption");
  const counter = document.getElementById("gallery-counter");

  if (!activeGalleryItems.length) {
    image.removeAttribute("src");
    image.alt = "";
    caption.textContent = "";
    counter.textContent = "";
    return;
  }

  const item = activeGalleryItems[activeGalleryIndex];
  image.src = item.src;
  image.alt = `${activeSiteFeature.properties.site} gallery image ${activeGalleryIndex + 1}`;
  caption.textContent = item.caption || "";
  counter.textContent = `${activeGalleryIndex + 1} / ${activeGalleryItems.length}`;
}

function stepGallery(direction) {
  if (!activeGalleryItems.length) {
    return;
  }

  activeGalleryIndex = (activeGalleryIndex + direction + activeGalleryItems.length) % activeGalleryItems.length;
  renderGalleryImage();
}

function formatMetric(value) {
  return Number(value).toLocaleString();
}

function buildSiteFlags() {
  sites.features.forEach((feature) => {
    const element = document.createElement("div");
    const body = document.createElement("div");
    const card = document.createElement("div");
    const label = document.createElement("strong");

    element.className = "site-flag";
    body.className = "site-flag-body";
    card.className = "site-flag-card";
    label.textContent = feature.properties.site;
    card.appendChild(label);
    body.appendChild(card);
    element.appendChild(body);

    const marker = new maplibregl.Marker({
      element,
      anchor: "center",
      offset: [0, -6],
      pitchAlignment: "viewport",
      rotationAlignment: "viewport"
    })
      .setLngLat(feature.geometry.coordinates)
      .addTo(map);

    siteFlags.set(feature.properties.id, { marker, element, feature });
  });
}

function showSiteFlag(feature) {
  const siteId = feature.properties.id;

  siteFlags.forEach(({ element }, id) => {
    element.classList.toggle("is-visible", id === siteId);
  });
}

function showCountryFlags(countryName) {
  siteFlags.forEach(({ element, feature }) => {
    element.classList.toggle("is-visible", feature.properties.country === countryName);
  });
}

function clearSiteDetail() {
  const detail = document.getElementById("site-detail");
  detail.classList.remove("is-visible");
  clearActiveSiteGallery();
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

  if (options.variant) {
    button.classList.add(`is-${options.variant}`);
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

function returnToGlobalView() {
  renderCountryButtons();
  globeSpin.enabled = false;
  globeSpin.flyToInProgress = true;
  showWorldTitle();

  map.once("moveend", () => {
    globeSpin.enabled = true;
    startGlobeSpin();
  });

  map.flyTo({
    center: globalView.center,
    zoom: globalView.zoom,
    pitch: globalView.pitch,
    bearing: globalView.bearing,
    speed: 0.72,
    curve: 1.55,
    essential: true
  });
}

function renderSiteButtons(countryName) {
  const list = document.getElementById("site-list");
  list.replaceChildren();

  list.appendChild(createHudButton("Back to all countries", returnToGlobalView, { variant: "back" }));

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
  hideWorldTitle();
  clearSiteDetail();
  renderSiteButtons(country.label);
  showCountryFlags(country.label);

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
  hideWorldTitle();
  activeSiteId = siteId;
  activeSiteFeature = feature;
  siteFlightId += 1;
  const thisSiteFlightId = siteFlightId;
  updateSiteDetail(feature);
  showSiteFlag(feature);
  hideGalleryTrigger();

  const revealGalleryWhenArrived = () => {
    if (activeSiteId !== siteId || siteFlightId !== thisSiteFlightId) {
      return;
    }

    showGalleryTrigger(feature);
  };

  map.flyTo({
    center: [site.longitude, site.latitude],
    zoom: site.zoom,
    pitch: site.pitch,
    bearing: site.bearing,
    speed: 0.72,
    curve: 1.55,
    essential: true
  });

  window.setTimeout(() => {
    if (activeSiteId !== siteId || siteFlightId !== thisSiteFlightId) {
      return;
    }

    if (map.isMoving()) {
      map.once("moveend", revealGalleryWhenArrived);
      return;
    }

    revealGalleryWhenArrived();
  }, 0);
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

document.getElementById("gallery-trigger").addEventListener("click", openGallery);
document.getElementById("gallery-close").addEventListener("click", closeGallery);
document.getElementById("gallery-prev").addEventListener("click", () => stepGallery(-1));
document.getElementById("gallery-next").addEventListener("click", () => stepGallery(1));
document.getElementById("about-link").addEventListener("click", openAbout);
document.getElementById("about-close").addEventListener("click", closeAbout);
document.getElementById("gallery-overlay").addEventListener("click", (event) => {
  if (event.target.id === "gallery-overlay") {
    closeGallery();
  }
});
document.getElementById("about-overlay").addEventListener("click", (event) => {
  if (event.target.id === "about-overlay") {
    closeAbout();
  }
});
window.addEventListener("keydown", (event) => {
  const galleryOpen = document.getElementById("gallery-overlay").classList.contains("is-visible");

  if (event.key === "Escape") {
    closeGallery();
    closeAbout();
  }

  if (!galleryOpen) {
    return;
  }

  if (event.key === "ArrowLeft") {
    stepGallery(-1);
  }

  if (event.key === "ArrowRight") {
    stepGallery(1);
  }
});

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

