library(httr2)
library(rvest)
library(atrrr)
library(webshot2)

# Helper function to extract HTML tag and/or URL
extract_tag <- function(html, xpath, href = FALSE) {
  if (href) {
    html |>
      html_elements(xpath = xpath) |>
      html_attr('href')
  } else {
    html |>
      html_elements(xpath = xpath) |>
      html_text() |>
      trimws()
  }
}


# Ping Yesterdays API
cat("Pinging Yesterdays API...\n")
georefs <- "https://yesterdays.maprva.org/api/v1/geojson/" |>
  request() |>
  req_user_agent("Yesterdays Bot (https://github.com/MapRVA/yesterdays_bot)") |>
  req_perform() |>
  resp_body_json()

# Randomly select a georeference
selected <- georefs[[2]][[sample(1:length(georefs[[2]]), 1)]]$properties

# Scrape metadata unavailable via API
cat("Scraping image metadata...\n")
selected_info <- selected$img_entry |>
  request() |>
  req_user_agent("Yesterdays Bot (https://github.com/MapRVA/yesterdays_bot)") |>
  req_perform() |>
  resp_body_html()

metadata <- data.frame(
  title = extract_tag(
    selected_info,
    '/html/body/main/div/div/div[1]/div[1]/div[1]/div[1]/h5'
  ),
  source = extract_tag(
    selected_info,
    '/html/body/main/div/div/div[1]/div[2]/div[1]/div[2]/dl/dd[1]/a'
  ),
  collection = extract_tag(
    selected_info,
    '/html/body/main/div/div/div[1]/div[2]/div[1]/div[2]/dl/dd[2]/a'
  ),
  date = selected$original_date,
  desc = extract_tag(
    selected_info,
    '/html/body/main/div/div/div[1]/div[2]/div[1]/div[2]/dl/dd[4]'
  ),
  source_url = extract_tag(selected_info, '//*[@id="source-link"]', href = T)
)

# Snapshot the georeference using Chromium
cat("Snapshotting the current georeference...\n")
webshot(
  url = selected$img_entry,
  file = 'georef.png',
  selector = ".map-container",
  delay = 10,
  useragent = "Yesterdays Bot (https://github.com/MapRVA/yesterdays_bot)",
  quiet = FALSE
)
list.files() # temporary for debugging

# Post to Bluesky
cat("Bluesky authentication...\n")
auth(
  user = 'yesterdaysbot.bsky.social',
  password = Sys.getenv("BSKY_PAT")
)

cat("Posting to Bluesky...\n")
post_skeet(
  text = paste0(
    metadata$title,
    ", ",
    metadata$date,
    "\n",
    metadata$source,
    ", ",
    metadata$collection,
    "\n",
    selected$img_entry,
    "\n",
    metadata$source_url
  ),
  image = c(selected$img_url),#, "georef.png"),
  image_alt = c(
    metadata$desc#,
    # paste0(
    #   "Georeference as of ",
    #   Sys.Date(),
    #   ". Picture shows a red dot in the center of a map with a gray cone representing the direction of the picture."
    # )
  )
)
