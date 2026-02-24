library(httr2)
library(rvest)
library(atrrr)
library(webshot2)

# Pick "from above" about 10% of the time
from_above <- sample(c(TRUE, FALSE), 1, prob = c(0.1, 0.9))
# Pick "georeferenced" about 75% of the time
georeferenced <- sample(c(FALSE, TRUE), 1, prob = c(0.25, 0.75))
cat(
  "Looking for georeferenced = ",
  georeferenced,
  "; from_above = ",
  from_above,
  ".\n",
  sep = ""
)


image_endpoint <- "https://yesterdays.maprva.org/api/v2/images/" |>
  request()

cat("Pinging Yesterdays API for number of images...\n")

n_images <- image_endpoint |>
  req_url_query(
    georeferenced = georeferenced,
    from_above = from_above,
    page_size = 1
  ) |>
  req_user_agent("Yesterdays Bot (https://github.com/MapRVA/yesterdays_bot)") |>
  req_perform() |>
  resp_body_json() |>
  _$count

cat(n_images, "images found.\n")

img <- sample(1:n_images, 1)

cat("Pinging Yesterdays API for information on image #", img, "...\n", sep = "")
selected <- image_endpoint |>
  req_url_query(
    georeferenced = georeferenced,
    from_above = from_above,
    page_size = 1,
    page = img
  ) |>
  req_user_agent("Yesterdays Bot (https://github.com/MapRVA/yesterdays_bot)") |>
  req_perform() |>
  resp_body_json() |>
  _$results[[1]]

### neeed to hit image API with ID directly
selected_full <- image_endpoint |>
  req_url_path_append(img) |>
  req_user_agent("Yesterdays Bot (https://github.com/MapRVA/yesterdays_bot)") |>
  req_perform() |>
  resp_body_json()

selected_full$url <- paste0("https://yesterdays.maprva.org/", selected_full$id)


cat(
  "Information gathered. Visit the image here: ",
  selected_full$url,
  "\n",
  sep = ""
)


cat("Bluesky authentication...\n")
auth(
  user = 'yesterdaysbot.bsky.social',
  password = Sys.getenv("BSKY_PAT")
)


if (isTRUE(georeferenced)) {
  # Snapshot the georeference using Chromium
  cat("Snapshotting the current georeference...\n")
  webshot(
    url = selected_full$url,
    file = 'georef.png',
    selector = ".map-container",
    delay = 2,
    useragent = "Yesterdays Bot (https://github.com/MapRVA/yesterdays_bot)",
    quiet = FALSE
  )
  cat(list.files())

  cat("Posting to Bluesky...\n")
  post_skeet(
    text = paste0(
      selected_full$title,
      ", ",
      selected_full$original_date,
      "\n",
      selected_full$collection$source_name,
      ", ",
      selected_full$collection$name,
      "\n",
      selected_full$url,
      "\n",
      selected_full$original_url
    ),
    image = c(selected_full$permalink, "georef.png"),
    image_alt = c(
      selected_full$description,
      paste0(
        "Georeference as of ",
        Sys.Date(),
        ". Picture shows a red dot in the center of a map with a gray cone representing the direction of the picture."
      )
    )
  )
} else {
  # "georeferenced" currently only refers to point references
  #   catch if from_above=T, georef=F and a polygonal reference still exists
  poly_ref_exists <- length(selected_full$from_above_georeferences) != 0

  if (from_above && poly_ref_exists) {
    cat("Snapshotting the current georeference...\n")
    webshot(
      url = selected_full$url,
      file = 'georef.png',
      selector = ".map-container",
      delay = 2,
      useragent = "Yesterdays Bot (https://github.com/MapRVA/yesterdays_bot)",
      quiet = FALSE
    )

    cat("Posting to Bluesky...\n")

    post_skeet(
      text = paste0(
        selected_full$title,
        ", ",
        selected_full$original_date,
        "\n",
        selected_full$collection$source_name,
        ", ",
        selected_full$collection$name,
        "\n",
        selected_full$url,
        "\n",
        selected_full$original_url
      ),
      image = c(selected_full$permalink, "georef.png"),
      image_alt = c(
        selected_full$description,
        paste0(
          "Georeference as of ",
          Sys.Date(),
          ". Picture shows a red dot in the center of a map with a gray cone representing the direction of the picture."
        )
      )
    )
  } else {
    georef_url <- ifelse(
      isTRUE(from_above),
      paste0(
        "https://yesterdays.maprva.org/polygonal-georeference/",
        selected$id
      ),
      paste0("https://yesterdays.maprva.org/georeference/?image=", selected$id)
    )

    cat("Posting to Bluesky...\n")
    post_skeet(
      text = paste0(
        "Think you know where this picture was taken? Give it a shot:\n",
        georef_url,
        "\n",
        selected_full$title,
        ", ",
        selected_full$original_date,
        "\n",
        selected_full$collection$source_name,
        ", ",
        selected_full$collection$name,
        "\n",
        selected_full$original_url
      ),
      image = selected_full$permalink,
      image_alt = selected_full$description
    )
  }
}
