library(RSQLite)
library(reshape2)
library(dplyr)
library(zoo)
library(ggplot2)


get_all_prices <- function() {
  print(paste('Fetching data:', Sys.time()))
  con <- dbConnect(RSQLite::SQLite(), dbname = '../data/stock_prices.sqlite')
  stock_prices <- dbReadTable(con, 'stock_prices')
  dbDisconnect(con)
  print(paste('Data fetched: ', Sys.time()))
  return(stock_prices)
}


format_prices <- function(stock_prices, position, date_range) {
  # reshape melted stock prices data
  start_date <- date_range[1]
  end_date <- date_range[2]
  universe <- unique(position$ticker)

  # get valid universe
  universe_valid <- universe[universe %in% stock_prices$Ticker]
  universe_uncovered <- universe[!(universe %in% stock_prices$Ticker)]
  
  if (length(universe_uncovered) > 0) {
    print(paste(
      'Tickers not covered:',
      paste(universe_uncovered, collapse = ', ')
    ))}

  if (length(universe_valid) == 0) {
    print('No available portfolio!')
    return(data.frame())
  }
  
  # reshape close prices & forward fill NA
  df <- stock_prices[stock_prices$Ticker %in% universe_valid, c('Date', 'Ticker', 'Close')]
  df$Close <- as.numeric(df$Close)
  df$Date <- as.Date(df$Date)
  df <- dcast(df, Date ~ Ticker, value.var = 'Close')
  df <- na.locf(df, fromLast = T)
  
  # reverse time index
  df <- df[rev(row.names(df)), ]
  df <- df[(df$Date >= start_date) & (df$Date <= end_date), ]
  return(df)
}


format_portfolio <- function(prices, position, date_range) {
  print('Formulating portfolio')
  start_date <- date_range[1]
  end_date <- date_range[2]
  init_prices <- prices[dim(prices)[1], ]
  universe_valid <- names(init_prices)[names(init_prices) != 'Date']

  # get initial number of shares
  shares <- sapply(
    universe_valid,
    function(x) {
      as.numeric(position[position$ticker == x, 'amount']) / as.numeric(init_prices[1, x]) })
  ptf <- data.frame(Date = prices$Date)
  ptf <- cbind(ptf, as.data.frame(sapply(
    universe_valid,
    function(x) {
      as.numeric(prices[, x]) * as.numeric(shares[x]) })))
  ptf$Portfolio <- apply(ptf[,-1], 1, sum)
  return(ptf)
  
}
