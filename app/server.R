library(bslib)
library(colorspace)
library(DT)
library(glue)
library(googlesheets4)
library(janitor)
library(plotly)
library(shiny)
library(thematic)
library(tidyverse)
library(yaml)
source("ui.R")

PLOT_FONT_SIZE <- 15
PLOT_FONT <- list(family = "Inter")
VAL_RED <- "#FF4655"
VAL_BLACK <- "#0F1923"

color_line <- VAL_RED
color_loss <- darken(VAL_RED, 0.3)
color_win <- VAL_BLACK
pal_win_loss <- c("Win" = color_win, "Loss" = color_loss)
options(gargle_oauth_cache = ".secrets") # for authentication

####### authenticating with Google #######
# Run gs4_auth() once, authenticate using the browser window that appears,
# and if the app runs for you, you can permanently re-comment it out.

# gs4_auth() # comment out if app is working
gs4_deauth()
gs4_auth(cache = ".secrets", email = Sys.getenv("EMAIL"))

# read data from Google Sheets
DATA_URL <- paste0(
  "https://docs.google.com/spreadsheets/d/1EdN0USO2oTRaY77LUpduruFPNn",
  "_00L8Ea8wjGBiZybY/edit?usp=sharing"
)
data <- read_sheet(DATA_URL)

###############################
####### START OF SERVER #######
###############################

server <- function(input, output, session) {
  # bs_themer() # for quickly scrolling through themes during development
  
  ####### FILTER DATA USING SIDEBAR FILTERS #######
  
  sel_data <- reactive({
    sel <- data |>
      filter(
        map %in% input$filter_map,
        agent %in% input$filter_agent,
        episode %in% input$filter_episode,
        act %in% input$filter_act
      ) |>
      mutate(map = factor(map))
    if (input$filter_vod) {
      sel <- filter(sel, !is.na(vod))
    }
    sel
  })
  
  ####### DYNAMIC FILTER OPTIONS BASED ON DATA #######
  
  observe({
    updateSelectInput(
      session, 
      "filter_map", 
      choices = sort(unique(data$map)),
      selected = sort(unique(data$map))
    )
  })
  
  observe({
    updateSelectInput(
      session, 
      "filter_agent", 
      choices = sort(unique(data$agent)),
      selected = sort(unique(data$agent))
    )
  })
  
  observe({
    updateSelectInput(
      session,
      "filter_episode", 
      choices = sort(unique(data$episode)),
      selected = sort(unique(data$episode))
    )
  })
  
  observe({
    updateSelectInput(
      session,
      "filter_act", 
      choices = sort(unique(data$act)),
      selected = sort(unique(data$act))
    )
  })
  
  ####### SUMMARY TAB ELEMENTS #######
  
  # win rate plot
  output$plt_winrate <- renderPlot({
    top <- sel_data() |>
      group_by(agent) |>
      summarise(n_games = n()) |>
      arrange(desc(n_games)) |>
      slice_head(n = 3)
    
    sel_data() |>
      group_by(agent, outcome) |>
      summarise(count = n()) |>
      ungroup() |>
      filter(agent %in% top$agent) |>
      pivot_wider(
        id_cols = agent, 
        names_from = outcome, 
        values_from = count
        ) |>
      mutate(winrate = Win / (Win + Loss)) |>
      left_join(top) |>
      arrange(desc(n_games)) |>
      mutate(
        agent = factor(agent, levels = unique(agent)) # order by number of games
        ) |>
      
      ggplot(aes(x = agent, y = winrate)) +
      geom_col(width = 0.5, fill = lighten(VAL_BLACK, 0.5)) +
      geom_hline(yintercept = 0.5, linewidth = 1, color = color_line) +
      geom_text(
       aes(y = winrate + 0.08, label = glue("{n_games} games")), 
       position = position_dodge(width = 0.9),
       vjust = 1,
       fontface = "bold",
       size = 4.5,
       color = VAL_BLACK
      ) +
      coord_cartesian(ylim = c(0,1)) +
      theme_minimal(base_size = PLOT_FONT_SIZE) +
      labs(
       x = element_blank(),
       y = "Win rate",
       title = "Win rate of most-played agents"
      ) +
      theme(
        text = element_text(family = "Inter"),
        axis.text = element_text(size = PLOT_FONT_SIZE - 3),
        plot.background = element_blank(),
        panel.background = element_blank()
      )
  })
  
  # scatter plot between headshot percent and kill-death ratio
  output$plt_headshot_kdr <- renderPlot({
    sel_data() |>
      filter(outcome != "Draw") |>
      ggplot(aes(x = headshot_pct, y = kdr, color = outcome)) +
      geom_point(size = 2, alpha = 0.3) +
      geom_smooth(method = "lm", se = FALSE) +
      scale_color_manual(values = pal_win_loss) +
      theme_minimal(base_size = PLOT_FONT_SIZE) +
      labs(
        x = "Headshot %",
        y = "Kill / death ratio",
        title = "KDR vs headshot percentage"
        ) +
      theme(
        text = element_text(family = "Inter"),
        legend.position = "top",
        legend.title = element_blank(),
        axis.text = element_text(size = PLOT_FONT_SIZE - 3),
        plot.background = element_blank(),
        panel.background = element_blank()
      )
  })
  
  # map kdr distribution
  output$plt_map_kdr <- renderPlot({
    sel_data() |>
      ggplot(aes(x = kdr, y = rev(map))) +
      geom_boxplot(color = VAL_BLACK) +
      geom_vline(xintercept = 1, linewidth = 0.8, color = color_line) +
      scale_x_continuous(breaks = 0:round(max(sel_data()$kdr), 0)) +
      theme_minimal(base_size = PLOT_FONT_SIZE) +
      labs(
        x = "Kill / death ratio",
        y = element_blank(),
        title = "Kill / death ratio by map"
      ) +
      theme(
        text = element_text(family = "Inter"),
        legend.position = "top",
        legend.title = element_blank(),
        axis.text = element_text(size = PLOT_FONT_SIZE - 3),
        plot.background = element_blank(),
        panel.background = element_blank()
      )
  })
  
  # damage delta distribution plots
  output$plt_dmg_delta <- renderPlot({
    sel_data() |>
      filter(outcome != "Draw") |>
      ggplot(aes(x = avg_dmg_delta, fill = outcome)) + 
      geom_density(alpha = 0.4, color = VAL_BLACK) +
      geom_vline(xintercept = 0, linewidth = 1, color = color_line) +
      theme_minimal(base_size = PLOT_FONT_SIZE) +
      scale_fill_manual(values = pal_win_loss) +
      labs(
        x = "Average damage delta",
        y = element_blank(),
        title = "Damage delta distribution by outcome"
      ) +
      theme(
        text = element_text(family = "Inter"),
        legend.position = "top",
        legend.title = element_blank(),
        axis.text = element_text(size = PLOT_FONT_SIZE - 3),
        plot.background = element_blank(),
        panel.background = element_blank()
      )
  })
  
  # most-played agent
  top <- reactive({
    sel_data() |>
      count(agent) |>
      arrange(desc(n)) |>
      slice_head(n = 1) |>
      pull(agent)
  })
  output$most_played_agent <- renderText({top()})
  
  # most-played agent game count
  output$top_agent_game_count <- reactive({
    sel_data() |>
      filter(agent == top()) |>
      nrow()
  })
  
  # most-played agent win rate
  output$top_agent_winrate <- reactive({
    sel_data() |>
      filter(agent == top()) |>
      group_by(outcome) |>
      summarise(count = n()) |>
      pivot_wider(names_from = outcome, values_from = count) |>
      rowwise() |>
      mutate(
        num_games = sum(c_across(where(is.numeric))),
        winrate = Win / num_games
        ) |>
      select(winrate) |>
      pull() |>
      round(2)
  })
  
  ####### DATA TAB ELEMENTS #######
  
  output$data_table <- renderDT({
    sel_data() |>
      clean_names(case = "sentence")
    },
    rownames = FALSE,
    options = list(scrollX = TRUE)
  )
}