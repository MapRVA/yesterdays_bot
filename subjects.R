library(httr2)
library(atrrr)
library(rtoot)
library(magick)
library(webshot2)

subject_endpoint <- "https://yesterdays.maprva.org/api/v2/subjects/"


subject <- subject_endpoint |>
  request() |>
  req_perform() |>
  resp_body_json()


subject <- subject_endpoint |>
  request() |>
  req_url_query(
    page_size = 1,
    page = sample(1:subject$count, 1)
  ) |>
  req_perform() |>
  resp_body_json() |>
  _$results[[1]]

imgs <- subject$images_url |>
  request() |>
  req_perform() |>
  resp_body_json()

imgs <- imgs$results[[sample(1:imgs$count, 1)]]

sub("_thumb$", '', imgs$thumbnail)

shot_outcome <- tryCatch(
  webshot(
    url = paste0("https://yesterdays.maprva.org/subjects/", subject$slug),
    file = 'subject.png',
    selector = "#subject-map",
    delay = 10,
    useragent = "Yesterdays Bot (https://github.com/MapRVA/yesterdays_bot)",
    quiet = FALSE
  ),
  warning = function(w) {
    "WARN!"
  },
  error = function(e) {
    "ERROR!"
  }
)


cat("   downloading image for Mastodon...\n")
image_read(sub("_thumb$", '', imgs$thumbnail)) |>
  image_write("toot_image.jpg", format = "jpeg")

prompt <- c(
  "Did you know that there are ",
  "That's a lot of random images. How about poking through the ",
  "How about checking out the "
)


post_body <- paste0(
  sample(prompt, 1),
  subject$image_count,
  " images tagged of \"",
  subject$title,
  "\"?\n",
  "https://yesterdays.maprva.org/subjects/",
  subject$slug,
  '\n',
  subject$wikidata$uri
)

alt_text <- paste(
  imgs$title,
  imgs$original_date,
  imgs$collection$name,
  imgs$collection$source_name,
  sep = "\n"
)

images_to_post <- "toot_image.jpg"

if (!(shot_outcome %in% c("WARN!", "ERROR!"))) {
  alt_text <- c(
    alt_text,
    paste0(
      "Georeferences as of ",
      Sys.Date(),
      ". Picture shows a field of blue dots in the center of a map representing georeferences of the subject."
    )
  )
  images_to_post <- c(images_to_post, "subject.png")
}


############
cat("Posting to Bluesky...\n")
auth(
  user = 'yesterdaysbot.bsky.social',
  password = Sys.getenv("BSKY_PAT")
)
post_skeet(
  text = post_body,
  image = images_to_post,
  image_alt = alt_text
)

cat("Posting to Mastodon")

post_toot(
  status = post_body,
  media = images_to_post,
  alt_text = alt_text
)
