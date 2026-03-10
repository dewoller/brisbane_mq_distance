# ABOUTME: Defines the 3 target locations with hardcoded coordinates
# ABOUTME: Returns an sf data frame with location ID, name, address, role, and geometry

library(sf)
library(tibble)

get_target_locations <- function() {
  tibble(
    location_id = c("loc_1", "loc_2", "loc_3"),
    name = c("Annerley", "Riverhills", "Fortitude Valley"),
    address = c(
      "628 Ipswich Road, Annerley",
      "9 Pallinup Street, Riverhills",
      "33 Baxter Street, Fortitude Valley"
    ),
    role = c("Candidate", "Candidate", "Current"),
    lon = c(153.0340, 152.9140, 153.0360),
    lat = c(-27.5100, -27.5590, -27.4560)
  ) |>
    st_as_sf(coords = c("lon", "lat"), crs = 4326)
}
