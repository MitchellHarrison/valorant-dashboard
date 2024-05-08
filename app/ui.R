library(bsicons)
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
INFO_ICON <- icon("circle-info", style = "opacity:0.3; font-size:15px")

####### tooltips #######
TT_HOW_TO_DELETE <- "To remove, left-click and press Backspace."
TT_PROP_TRAIN <- paste(
  "This is the proportion of the data that is used for training the model.",
  "The rest of the data are reserved for testing the performance of the model.",
  "A higher value may result in a more accurate model, but with a smaller",
  "data set to test against, leading to lower confidence in model performance.",
  "Recommended: 80%"
)
TT_CONFIDENCE_LEVEL <- paste(
  "This changes the level at which a factor is considered \"significant\".",
  "Lower values mean more significant variables are displayed. Higher values",
  "mean more variables will be displayed, but they may have less influence",
  "on the outcome. Recommended: 0.05"
)
TT_MODEL_FACTORS <- paste(
  "These are the variables that the model is testing. To remove any,",
  "left-click and press Backspace on your keyboard. By default, all variables",
  "are used."
)
TT_SIG_FACTORS <- paste(
  "These are the factors that the model finds to be significant given the",
  "selected level of confidence. Negative ESTIMATE values mean that a",
  "decrease in that stat means an increase in odds of winning. Lower P VALUES",
  "mean a factor is more significant."
)
TT_MODEL_PERF <- paste(
  "This table shows the model's performance on testing data. It",
  "tells you what the model guess (PREDICTION) vs. what the correct answer was",
  "(TRUTH) in the testing data. The FREQ column is the number of times that a",
  "prediction/truth combination occur."
)
TT_ROC_CURVE <- paste(
  "The sharper the upper-left curve of this graph, the better the model is",
  "performing. The AUC value is considered \"acceptable\" between 0.7 and 0.8,",
  "\"excellent\" between 0.8 and 0.9, and \"outstanding\" above 0.9."
)
###########################
####### START OF UI #######
###########################

ui <- page_navbar(
  theme = theme,
  title = APP_TITLE,
  sidebar = sidebar(
    width = 300,
    h4("Global filters:", INFO_ICON) |>
      tooltip("These filters add or remove data across every tab."),
    
    # filter games that have vods
    checkboxInput(
      "filter_vod",
      "Only games with a vod",
      value = FALSE
    ) |>
      tooltip("Remove games without a VOD. Not recommended in most cases."),
    
    # map filter
    selectInput(
      "filter_map",
      "Maps:",
      choices = NULL,
      selected = NULL,
      multiple = TRUE
    ) |>
      tooltip(TT_HOW_TO_DELETE),
    
    # agent filter
    selectInput(
      "filter_agent",
      "Agents:",
      choices = NULL,
      selected = NULL,
      multiple = TRUE
    ) |>
      tooltip(TT_HOW_TO_DELETE),
    
    # episode filter
    selectInput(
      "filter_episode",
      "Episode(s):",
      choices = NULL,
      selected = NULL,
      multiple = TRUE
    ) |>
      tooltip(TT_HOW_TO_DELETE),
    
    # act filter
    selectInput(
      "filter_act",
      "Act(s):",
      choices = NULL,
      selected = NULL,
      multiple = TRUE
    ) |>
      tooltip(TT_HOW_TO_DELETE)
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
        ) |>
          tooltip(TT_MODEL_FACTORS),
        
        sliderInput(
          "model_alpha",
          "Confidence level:",
          min = 0.01,
          max = 0.2,
          value = 0.05,
          step = 0.01,
          ticks = FALSE
        ) |>
          tooltip(TT_CONFIDENCE_LEVEL),
        
        sliderInput(
          "prop_train",
          "Pct. of data for training:",
          min = 50,
          max = 95,
          value = 80,
          step = 5,
          ticks = FALSE
        ) |>
          tooltip(TT_PROP_TRAIN)
      ),
      
      column(
        width = 9,
        fluidRow(
          column(
            width = 6,
            h5("Significant factors", INFO_ICON) |>
              tooltip(TT_SIG_FACTORS),
            DTOutput("significant_factors")
          ),
          column(
            width = 6,
            h5("Model performance", INFO_ICON) |>
              tooltip(TT_MODEL_PERF),
            DTOutput("conf_matrix")
          )
        ),
        fluidRow(
          column(
            width = 6
          ),
          column(
            width = 6,
            card(
              card_header("Model ROC curve:", INFO_ICON) |>
                tooltip(TT_ROC_CURVE),
              plotOutput("roc_curve")
            )
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