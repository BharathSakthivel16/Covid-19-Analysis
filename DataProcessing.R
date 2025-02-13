
#DATA PROCESSING AND CLEANING
data_confirmed <- read.csv("D:/BDA/Projects/R-Shiny/COVID-19_Analysis/data/time_series_covid19_confirmed_global.csv",sep=',', head=TRUE,check.names =FALSE )
data_deceased <- read.csv("D:/BDA/Projects/R-Shiny/COVID-19_Analysis/data/time_series_covid19_deaths_global.csv",sep=',', head=TRUE,check.names =FALSE)
data_recovered <- read.csv("D:/BDA/Projects/R-Shiny/COVID-19_Analysis/data/time_series_covid19_recovered_global.csv",sep=',', head=TRUE,check.names =FALSE)
data_weather <- read.csv("D:/BDA/Projects/R-Shiny/COVID-19_Analysis/data/covid_weather_dataset.csv")


current_date <- as.Date(names(data_confirmed)[ncol(data_confirmed)], format = "%m/%d/%y")
changed_date <- file.info("data/covid19JHU.zip")$mtime

# Get data by country
#Confirmed Cases
data_confirmed_sub <- data_confirmed %>%
  pivot_longer(names_to = "date", cols = 5:ncol(data_confirmed)) %>%
  group_by(`Province/State`, `Country/Region`, date, Lat, Long) %>%
  summarise("confirmed" = sum(value, na.rm = T))

#Recovered Cases
data_recovered_sub <- data_recovered %>%
  pivot_longer(names_to = "date", cols = 5:ncol(data_recovered)) %>%
  group_by(`Province/State`, `Country/Region`, date, Lat, Long) %>%
  summarise("recovered" = sum(value, na.rm = T))

#Deceased Cases
data_deceased_sub <- data_deceased %>%
  pivot_longer(names_to = "date", cols = 5:ncol(data_deceased)) %>%
  group_by(`Province/State`, `Country/Region`, date, Lat, Long) %>%
  summarise("deceased" = sum(value, na.rm = T))

data_evolution <- data_confirmed_sub %>%
  full_join(data_deceased_sub) %>%
  ungroup() %>%
  mutate(date = as.Date(date, "%m/%d/%y")) %>%
  arrange(date) %>%
  group_by(`Province/State`, `Country/Region`, Lat, Long) %>%
  mutate(
    recovered = abs(lag(confirmed, 14, default = 0) - deceased),
    recovered = ifelse(recovered > 0, recovered, 0),
    active = abs(confirmed - recovered - deceased) #assessing active cases)
  ) %>%
  pivot_longer(names_to = "var", cols = c(confirmed, recovered, deceased, active)) %>%
  ungroup()

# Calculating new cases
data_evolution <- data_evolution %>%
  group_by(`Province/State`, `Country/Region`) %>%
  mutate(value_new = abs(value - lag(value, 4, default = 0))) %>%
  ungroup()

#Accessing population here to calculate per 100k parameters in data table
population <- wb(country = "countries_only", indicator = "SP.POP.TOTL", startdate = 2018, enddate = 2020) %>%
  select(country, value) %>%
  rename(population = value)
countryNamesPop <- c("Brunei Darussalam", "Congo, Dem. Rep.", "Congo, Rep.", "Czech Republic", "Egypt, Arab Rep.", "Iran, Islamic Rep.", "Korea, Rep.", "St. Lucia", "West Bank and Gaza", "Russian Federation", "Slovak Republic", "United States", "St. Vincent and the Grenadines", "Venezuela, RB")
countryNamesDat  <- c("Brunei", "Congo (Kinshasa)", "Congo (Brazzaville)", "Czechia", "Egypt", "Iran", "Korea, South", "Saint Lucia", "occupied Palestinian territory", "Russia", "Slovakia", "US", "Saint Vincent and the Grenadines", "Venezuela")
population[ which(population$country %in% countryNamesPop), "country"] <- countryNamesDat

noDataCountries <- data.frame(
  country = c("Cruise Ship", "Guadeloupe", "Guernsey", "Holy See", "Jersey", "Martinique", "Reunion", "Taiwan*"),
  population = c(3700, 395700, 63026, 800, 106800, 376480, 859959, 23780452)
)
population <- bind_rows(population, noDataCountries)
population <- population[duplicated(population$country),] 
colnames(data_evolution) <- gsub(".x", '', names(data_evolution))
data_evolution <- data_evolution %>%
  left_join(population, by = c("Country/Region" = "country"))
