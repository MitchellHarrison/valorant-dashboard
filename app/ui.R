library(bslib)
library(DT)
library(shiny)
library(thematic)
library(plotly)
thematic_shiny(font = "auto")

####### constants #######
APP_TITLE <- "Valorant Ranked Tracker"
BW_THEME <- "zephyr"
VAL_BLACK <- "#0F1923"
model_options <- c("Agent", "Map", "Kills", "Deaths", "Assists", "K/D Ratio",
                   "Avg. Damage Delta", "Headshot %", "Avg. Damage", "ACS",
                   "Frag Number")
model_options <- sort(model_options)
theme <- bs_theme(bootswatch = BW_THEME, fg = VAL_BLACK, bg = "#fff")

###########################
####### START OF UI #######
###########################

ui <- page_navbar(
  theme = theme,
  title = APP_TITLE,
  sidebar = sidebar(
    width = 300,
    
    # filter games that have vods
    checkboxInput(
      "filter_vod",
      "Only games with a vod",
      value = FALSE
    ),
    
    # map filter
    selectInput(
      "filter_map",
      "Maps:",
      choices = NULL,
      selected = NULL,
      multiple = TRUE
    ),
    
    # agent filter
    selectInput(
      "filter_agent",
      "Agents:",
      choices = NULL,
      selected = NULL,
      multiple = TRUE
    ),
    
    # episode filter
    selectInput(
      "filter_episode",
      "Episode(s):",
      choices = NULL,
      selected = NULL,
      multiple = TRUE
    ),
    
    # act filter
    selectInput(
      "filter_act",
      "Act(s):",
      choices = NULL,
      selected = NULL,
      multiple = TRUE
    )
  ),
  
  ####### SUMMARY PANEL #######
  
  nav_panel(
    title = "Summary",
    fluidRow(
      column(
        width = 6,
        card(
          height = 300,
          plotOutput("plt_winrate"),
        ),
        card(plotOutput("plt_headshot_kdr"))
      ),
      column(
        width = 6,
        card(plotOutput("plt_map_kdr")),
        card(
          height = 300,
          plotOutput("plt_dmg_delta")
        )
      )
    )
  ),
  
  ####### MODELLING PANEL #######
  
  nav_panel(
    title = "Modelling",
    fluidRow(
      column(
        width = 3,
        selectInput(
          "model_factors",
          "Factors:",
          choices = model_options,
          selected = model_options,
          multiple = TRUE
        ),
        sliderInput(
          "model_alpha",
          "Confidence level:",
          min = 0.01,
          max = 0.2,
          value = 0.05,
          step = 0.01,
          ticks = FALSE
        ),
        sliderInput(
          "prop_train",
          "Pct. of data for training:",
          min = 50,
          max = 95,
          value = 80,
          step = 5,
          ticks = FALSE
        )
      ),
      column(
        width = 9,
        fluidRow(
          column(
            width = 6,
            h5("Significant factors"),
            DTOutput("significant_factors")        
          ),
          column(
            width = 6,
            h5("Model performance"),
            DTOutput("conf_matrix")
          )
        ),
        fluidRow(
          column(
            width = 6
          ),
          column(
            width = 6,
            card(plotOutput("roc_curve"))
          )
        )
      )
    )
  ),
  
  ####### DATA PANEL ########
  
  nav_panel(
    title = "Data",
    DTOutput("data_table")
  )
)