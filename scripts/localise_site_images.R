slug <- function(x) {
  x <- tolower(gsub("[^A-Za-z0-9]+", "-", x))
  gsub("(^-+|-+$)", "", x)
}

sites_file <- file.path("data", "sites.csv")
sites <- read.csv(sites_file, stringsAsFactors = FALSE, check.names = FALSE)

commons_file_url <- function(filename) {
  paste0(
    "https://commons.wikimedia.org/wiki/Special:FilePath/",
    URLencode(filename, reserved = TRUE),
    "?width=640"
  )
}

commons_page_url <- function(filename) {
  paste0(
    "https://commons.wikimedia.org/wiki/File:",
    URLencode(filename, reserved = TRUE)
  )
}

replacement_images <- list(
  "monteverde-cloud-forest" = list(
    file = "Monteverde_Cloud_Forest_02.jpg",
    credit = "Cephas, CC BY-SA 4.0"
  ),
  "tortuguero-lowland-forest" = list(
    file = "Tortuguero_boat_trip.JPG",
    credit = "Lars0001, Wikimedia Commons"
  ),
  "osa-peninsula-rainforest" = list(
    file = "Corcovado_National_Park,_Costa_RIca_02.jpg",
    credit = "Wikimedia Commons, CC0"
  ),
  "la-selva-biological-station" = list(
    file = "Laselva1.jpg",
    credit = "Jimfbleak at English Wikipedia, CC BY-SA 3.0"
  ),
  "guanacaste-dry-forest" = list(
    file = "Guanacaste_National_Park.jpg",
    credit = "Wikimedia Commons"
  ),
  "khao-yai-evergreen-forest" = list(
    file = "Khao_Yai_National_Park.jpg",
    credit = "Kawpodmd, CC BY-SA 3.0 / GFDL"
  ),
  "kaeng-krachan-forest" = list(
    file = "Kaeng_Krachan.jpg",
    credit = "JJ Harrison, Wikimedia Commons"
  ),
  "ueno-urban-park" = list(
    file = "Ueno_park.jpg",
    credit = "Bernard Gagnon, Wikimedia Commons"
  )
)

for (i in seq_len(nrow(sites))) {
  country_dir <- slug(sites$country[i])
  site_dir <- slug(sites$site[i])
  image_dir <- file.path("data", "images", country_dir, site_dir)
  image_file <- file.path(image_dir, "photo.jpg")
  source_url <- sites$photo_url[i]

  replacement <- replacement_images[[sites$id[i]]]
  if (!is.null(replacement)) {
    source_url <- commons_file_url(replacement$file)
    sites$photo_credit[i] <- replacement$credit
    sites$photo_link[i] <- commons_page_url(replacement$file)
  }

  dir.create(image_dir, recursive = TRUE, showWarnings = FALSE)

  if (!file.exists(image_file) || file.info(image_file)$size == 0) {
    download.file(source_url, image_file, mode = "wb", quiet = TRUE)
  }

  sites$photo_url[i] <- gsub("\\\\", "/", image_file)
}

write.csv(sites, sites_file, row.names = FALSE, na = "")
