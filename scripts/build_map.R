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

about <- read_json(file.path(data_dir, "about.json"), simplifyVector = TRUE)

make_id <- function(value) {
  value <- tolower(value)
  value <- gsub("[^a-z0-9]+", "-", value)
  gsub("(^-|-$)", "", value)
}

local_path <- function(path) {
  gsub("\\\\", "/", path)
}

escape_html <- function(value) {
  value <- as.character(value)
  value <- gsub("&", "&amp;", value, fixed = TRUE)
  value <- gsub("<", "&lt;", value, fixed = TRUE)
  value <- gsub(">", "&gt;", value, fixed = TRUE)
  value <- gsub('"', "&quot;", value, fixed = TRUE)
  gsub("'", "&#39;", value, fixed = TRUE)
}

render_about_content <- function(about) {
  paragraphs <- paste0(
    "        <p>",
    escape_html(about$paragraphs),
    "</p>",
    collapse = "\n"
  )

  links <- vapply(
    seq_len(nrow(about$links)),
    function(i) {
      link <- about$links[i, ]
      paste0(
        "          <a class=\"about-logo-link\" href=\"", escape_html(link$url), "\" target=\"_blank\" rel=\"noopener\">\n",
        "            <strong>", escape_html(link$title), "</strong>\n",
        "            <span>", escape_html(link$subtitle), "</span>\n",
        "          </a>"
      )
    },
    character(1)
  )

  paste(
    paragraphs,
    "",
    paste0("        <h3>", escape_html(about$link_heading), "</h3>"),
    "        <div class=\"about-links\">",
    paste(links, collapse = "\n"),
    "        </div>",
    sep = "\n"
  )
}

gallery_items <- function(photo_url) {
  gallery_dir <- file.path(project_dir, dirname(photo_url), "gallery")

  if (!dir.exists(gallery_dir)) {
    return(list())
  }

  files <- list.files(
    gallery_dir,
    pattern = "\\.(jpg|jpeg|png|webp)$",
    full.names = FALSE,
    ignore.case = TRUE
  )

  files <- sort(files)

  if (!length(files)) {
    return(list())
  }

  captions_file <- file.path(gallery_dir, "captions.csv")
  captions <- setNames(rep("", length(files)), files)

  if (file.exists(captions_file)) {
    captions_data <- read.csv(captions_file, stringsAsFactors = FALSE, check.names = FALSE)

    if (all(c("image", "caption") %in% names(captions_data))) {
      matched <- match(files, captions_data$image)
      captions <- ifelse(is.na(matched), "", captions_data$caption[matched])
    }
  }

  unname(Map(
    function(file, caption) {
      list(
        src = local_path(file.path(dirname(photo_url), "gallery", file)),
        caption = caption
      )
    },
    files,
    captions
  ))
}

validate_site_assets <- function(sites) {
  errors <- character()

  duplicate_ids <- unique(sites$id[duplicated(sites$id)])
  if (length(duplicate_ids)) {
    errors <- c(
      errors,
      paste0("Duplicate site IDs: ", paste(duplicate_ids, collapse = ", "))
    )
  }

  for (i in seq_len(nrow(sites))) {
    site_id <- sites$id[i]
    photo_url <- sites$photo_url[i]
    photo_path <- file.path(project_dir, photo_url)

    if (!file.exists(photo_path)) {
      errors <- c(errors, paste0(site_id, ": photo_url does not exist: ", local_path(photo_url)))
    }

    gallery_dir <- file.path(project_dir, dirname(photo_url), "gallery")
    if (!dir.exists(gallery_dir)) {
      next
    }

    gallery_files <- sort(list.files(
      gallery_dir,
      pattern = "\\.(jpg|jpeg|png|webp)$",
      full.names = FALSE,
      ignore.case = TRUE
    ))

    missing_gallery_files <- gallery_files[!file.exists(file.path(gallery_dir, gallery_files))]
    if (length(missing_gallery_files)) {
      errors <- c(
        errors,
        paste0(site_id, ": gallery image file is missing: ", paste(missing_gallery_files, collapse = ", "))
      )
    }

    captions_file <- file.path(gallery_dir, "captions.csv")
    if (length(gallery_files) && !file.exists(captions_file)) {
      errors <- c(errors, paste0(site_id, ": captions.csv is missing for gallery"))
      next
    }

    if (!file.exists(captions_file)) {
      next
    }

    captions_data <- tryCatch(
      read.csv(captions_file, stringsAsFactors = FALSE, check.names = FALSE),
      error = function(error) {
        errors <<- c(errors, paste0(site_id, ": captions.csv could not be read: ", error$message))
        NULL
      }
    )

    if (is.null(captions_data)) {
      next
    }

    if (!all(c("image", "caption") %in% names(captions_data))) {
      errors <- c(errors, paste0(site_id, ": captions.csv must contain image and caption columns"))
      next
    }

    duplicate_caption_images <- unique(captions_data$image[duplicated(captions_data$image)])
    if (length(duplicate_caption_images)) {
      errors <- c(
        errors,
        paste0(site_id, ": captions.csv has duplicate image rows: ", paste(duplicate_caption_images, collapse = ", "))
      )
    }

    extra_caption_rows <- setdiff(captions_data$image, gallery_files)
    missing_caption_rows <- setdiff(gallery_files, captions_data$image)

    if (length(extra_caption_rows)) {
      errors <- c(
        errors,
        paste0(site_id, ": captions.csv references missing gallery images: ", paste(extra_caption_rows, collapse = ", "))
      )
    }

    if (length(missing_caption_rows)) {
      errors <- c(
        errors,
        paste0(site_id, ": gallery images missing captions.csv rows: ", paste(missing_caption_rows, collapse = ", "))
      )
    }
  }

  if (length(errors)) {
    stop(
      paste(c("Site asset validation failed:", paste0("- ", errors)), collapse = "\n"),
      call. = FALSE
    )
  }
}

validate_site_assets(sites)

sites_sf <- st_as_sf(
  sites,
  coords = c("lon", "lat"),
  crs = 4326,
  remove = FALSE
)

map_bbox <- st_bbox(st_geometry(sites_sf))
center_lon <- mean(c(map_bbox[["xmin"]], map_bbox[["xmax"]]))
center_lat <- mean(c(map_bbox[["ymin"]], map_bbox[["ymax"]]))

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
        number_of_nights = number_of_nights,
        number_of_images = number_of_images,
        number_of_detections = number_of_detections,
        setting = setting,
        photo_url = photo_url,
        photo_credit = photo_credit,
        photo_link = photo_link,
        gallery_items = gallery_items(photo_url)
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
      country == "Thailand" ~ 4.8,
      site_count == 1 ~ 10.4,
      pmax(lon_span, lat_span) < 0.75 ~ 9.0,
      pmax(lon_span, lat_span) < 5 ~ 5.2,
      TRUE ~ 2.2
    ),
    pitch = case_when(
      country == "Thailand" ~ 42,
      site_count == 1 ~ 45,
      TRUE ~ 52
    ),
    bearing = case_when(
      country == "Anguilla" ~ -18,
      country == "Thailand" ~ 0,
      TRUE ~ -8
    )
  ) |>
  select(id, label, longitude, latitude, zoom, pitch, bearing, site_count) |>
  toJSON(
    dataframe = "rows",
    auto_unbox = TRUE,
    pretty = TRUE,
    digits = 8
  )

template_file <- file.path(project_dir, "templates", "index.html")
html <- paste(readLines(template_file, warn = FALSE), collapse = "\n")

html <- gsub("__SITES_GEOJSON__", sites_geojson, html, fixed = TRUE)
html <- gsub("__POI_SITES__", poi_sites_json, html, fixed = TRUE)
html <- gsub("__COUNTRY_VIEWS__", country_views_json, html, fixed = TRUE)
html <- gsub("__CENTER_LON__", sprintf("%.8f", center_lon), html, fixed = TRUE)
html <- gsub("__CENTER_LAT__", sprintf("%.8f", center_lat), html, fixed = TRUE)
html <- gsub("__ABOUT_TITLE__", escape_html(about$title), html, fixed = TRUE)
html <- gsub("__ABOUT_CONTENT__", render_about_content(about), html, fixed = TRUE)

output_file <- file.path(project_dir, "index.html")
writeLines(html, output_file, useBytes = TRUE)

message("Wrote interactive globe site: ", output_file)


