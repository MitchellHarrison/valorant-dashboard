library(bsicons)
library(bslib)
library(DT)
library(shiny)
library(plotly)

####### constants #######

APP_TITLE <- "Valorant Ranked Tracker"
REPO_URL <- "https://github.com/MitchellHarrison/valorant-dashboard"
BW_THEME <- "quartz"
VAL_RED <- "#FF4655"
VAL_BLACK <- "#0F1923"
INFO_ICON <- icon("circle-info", style = "opacity:0.3; font-size:15px;")
VOD_ISSUE_URL <- paste0(
  "https://github.com/MitchellHarrison/valorant-dashboard/issues/new?",
  "assignees=mitchellharrison&labels=public+vod+request&projects=&template=",
  "PUBLIC-VOD.yml&title=Public+VOD+request"
)
VOD_PRIVACY_NOTE <- paste0(
  "<em>Note: All of my VODs are private on YouTube by default. To request that ",
  "a VOD be made public, submit a GitHub issue with the game ID ",
  "<a href='", VOD_ISSUE_URL ,"'>here</a></em>."
)
model_options <- c("Agent", "Map", "Kills", "Deaths", "Assists", "K/D Ratio",
                   "Avg. Damage Delta", "Headshot %", "Avg. Damage", "ACS",
                   "Frag Number")

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
  "mean a factor is more significant that factors with a higher P VALUE."
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
  title = APP_TITLE,
  theme = bs_theme(version = 5, bootswatch = "zephyr", primary = VAL_RED),
  sidebar = sidebar(
    width = 300,
    shinyWidgets::chooseSliderSkin(
      skin = "Modern", 
      color = colorspace::lighten(VAL_BLACK, 0.5)
    ),
    
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
    sliderInput(
      "filter_episode",
      "Episode(s):",
      min = 1,
      max = 8,
      value = c(1,8),
      ticks = FALSE
    ),
    
    # act filter
    sliderInput(
      "filter_act",
      "Act(s):",
      min = 1,
      max = 3,
      value = c(1,3),
      ticks = FALSE
    ),
    
    # scoreboard position filter
    sliderInput(
      "filter_n_frag",
      "Scoreboard Position:",
      min = 1,
      max = 5,
      value = c(1,5),
      ticks = FALSE,
      step = 1
    ),
    
    # kdr filter
    sliderInput(
      "filter_kdr",
      "Kill / Death Ratio:",
      min = 0,
      max = 10,
      value = c(0,10),
      ticks = FALSE,
      step = 0.1
    ),
    
    # acs filter
    sliderInput(
      "filter_acs",
      "Average Combat Score:",
      min = 0,
      max = 500,
      value = c(0,500),
      ticks = FALSE,
      step = 1
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
          plotOutput("plt_winrate")
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
  
  ####### MODELING PANEL #######
  
  nav_panel(
    title = "Modeling",
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
            DTOutput("significant_factors"),
            br(),
            
            h5("Model performance", INFO_ICON) |>
              tooltip(TT_MODEL_PERF),
            DTOutput("conf_matrix")
          ),
          
          # ROC curve and performance stats
          column(
            width = 6,
            
            # ROC curve
            fluidRow(
              card(
                card_header("Model ROC curve:", INFO_ICON) |>
                  tooltip(TT_ROC_CURVE),
                plotOutput("roc_curve")
              )
            ),
            br(),
            
            # model performance statistics
            fluidRow(
              column(
                width = 4,
                h6("Training Points:"),
                textOutput("training_points")
              ),
              column(
                width = 4,
                h6("Accuracy"),
                textOutput("model_acc"),
              ),
              column(
                width = 4,
                h6("Precision"),
                textOutput("model_precision")
              )
            ),
          )
        )
      )
    )
  ),
  
  ####### VOD REVIEW PANEL #######
  
  nav_panel(
    title = "VOD Review",
    fluidRow(
      column(
        width = 3,
        selectInput(
          "vod_id",
          "Game ID:",
          choices = NULL,
          selected = NULL
        ),
        
        fluidRow(
          column(
            width = 6,
            h6("Episode:"),
            textOutput("vod_episode")
          ),
          column(
            width = 6, 
            h6("Rank:"),
            textOutput("vod_rank")
          )
        ),
        br(),
        
        fluidRow(
          column(
            width = 6,
            h6("Agent:"),
            textOutput("vod_agent")
          ),
          column(
            width = 6, 
            h6("Outcome:"),
            textOutput("vod_outcome")
          )
        ),
        br(),
        
        fluidRow(
          h6("KDR:"),
          textOutput("vod_kdr"),
          plotOutput("plt_mini_kdr", height = 60)
        ),
        br(),
        
        fluidRow(
          h6("ACS:"),
          textOutput("vod_acs"),
          plotOutput("plt_mini_acs", height = 60)
        ),
        br(),
        
        fluidRow(
          h6("Headshot %:"),
          textOutput("vod_headshot"),
          plotOutput("plt_mini_headshot", height = 60)
        ),
        br(),
        
        fluidRow(
          h6("Average Damage:"),
          textOutput("vod_avg_dmg"),
          plotOutput("plt_mini_avg_dmg", height = 60)
        )
      ),
      
      column(
        width = 9,
        card(
          htmlOutput("vod_window")
        ),
        
        # VOD privacy note
        HTML(paste0(
          "<div style='padding-left: 60px; padding-right: 60px;",
          "text-align:center;'>", VOD_PRIVACY_NOTE, "</div>"
        ))
      )
    )
  ),
  
  ####### DATA PANEL ########
  
  nav_panel(
    title = "Raw Data",
    DTOutput("data_table")
  ),
  
  ####### REPO URL IN NAVBAR #######
  
  nav_spacer(),
  nav_item(a(href = REPO_URL, "Made with 🤍 by Mitch Harrison."))
)
