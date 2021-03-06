#'@title Simulation and bootstrap of Threshold Autoregressive model (SETAR)
#'
#'@description Simulate or bootstrap a Threshold AR (SETAR)
#'The \code{setar.sim} function allows to simulate a SETAR model from scratch. 
#'The most important argument is the \code{B} argument, which should be a one row matrix, 
#'with first the constant/trend arguments, then the 
#'slope coefficients, and this for each regime (lower, middle, high). 
#'Other arguments such as \code{lag}, \code{nthresh} indicate the dimension of this matrix. 
#'As an example, a SETAR with 2 lags, 1 threshold, a constant, would have coefficient in the order:
#' \code{c(const_L, phi_1_L, phi_2_L, const_H, phi_1_H, phi_2_H)} where L is for Lower regime, H for Higher. 
#'
#'\code{setar.boot} on the other side resample/bootstraps an existing setar output. 
#'It uses a recursive approach, reconstructing the series. 
#'Residuals from the original model are resampled using different bootstrap schemes, see  \code{\link{resample_vec}}. 
#'
#'@param B Simulation: vector of coefficients to simulate from. 
#'@param Thresh,nthresh,lag,include Simulation: parameters for the SETAR to simulate. 
#'See \code{\link{setar}} for their description.  
#'@param innov Simulation: time series of innovations/residuals. 
#'@param n Simulation: Number of observations to simulate.
#'@param starting Simulation: Starting values (same length as lag)
#'@param setarObject Bootstrap: the \code{\link{setar}} object to resample data from.
#'@param boot.scheme Bootstrap: which resampling scheme to use for the residuals. See \code{\link{resample_vec}}. 
#'@param seed Bootstrap: seed used in the resampling
#'@param \dots additional arguments for the unexported \code{setar.gen}.  
#'@return a list with the simulated/bootstrapped data and the parameter matrix
#'used.
#'@author Matthieu Stigler
#'@seealso \code{\link{SETAR}} to estimate a SETAR, \code{\link{arima.sim}} to
#'simulate an ARMA.
#'@keywords ts
#'@examples
#'
#'##Simulation of a TAR with 1 threshold
#' TvarMat <- c(2.9,-0.4,-0.1,-1.5, 0.2,0.3)
#'sim<-setar.sim(B=TvarMat,lag=2, type="simul", nthresh=1, Thresh=2, starting=c(2.8,2.2))
#'mean(ifelse(sim>2,1,0))	#approximation of values over the threshold
#'
#'#check the result
#'selectSETAR(sim, m=2)
#'
#'##Bootstrap a TAR with two threshold (three regimes)
#'sun <- (sqrt(sunspot.year+1)-1)*2
#'sun_est <- setar(sun, nthresh=2, m=2)
#'sun_est_boot <- setar.boot(sun_est)
#'head(sun_est_boot)
#'
#'##Check the bootstrap: with no resampling, is it the same series?
#'sun_est_boot <- setar.boot(sun_est, boot.scheme = "check")
#'all.equal(as.numeric(sun), sun_est_boot)
#'
#' @name setar.sim
NULL # for roxygen, do not add 

setar.gen <- function(B, n=200, lag=1, include=c("const", 'trend', "none", "both"), 
                      nthresh=0, thDelay=0, Thresh, 
                      trendStart=1, 
                      starting=NULL,  innov, exo, 
                      round_digits = 10,
                      returnStarting = FALSE,
                      add.regime =FALSE,
                      show.parMat = FALSE, ...){
  
  ## Check arguments
  if(!nthresh %in% c(0,1,2))  stop("arg nthresh should be either 0,1 or 2")
  include <- match.arg(include)
  npar_mat <- switch(include, const=lag+1, none=lag, trend = lag +1, both = lag + 2)
  
  ## check specification of B
  if(npar_mat *(nthresh+1)!=length(B))
    stop("Matrix B badly specified")
  if(!is.null(starting) && length(starting)!=lag)
    stop("Bad specification of starting values. Should have as many values as the number of lags")
  
  ## y vec, trend vec
  n_full <- n + lag
  y <- vector("numeric", length = n_full)
  if(!is.null(starting)) y[seq_len(lag)] <- starting  
  trend <- c(rep(0, lag), trendStart+(0:(n-1)))  ### n-1 a starts from zero
  regime <- vector("numeric", length=n_full)
  
  ## exo
  if(missing(exo)) exo <- rep(0, n_full)
  if(length(exo)!= n_full) stop("'exo' should be of same length as n+lag (though first lag values discarded) ")
  
  ## Extend B
  Bfull <- matrix(rep(0, (lag+2)*(nthresh+1)), nrow = 1)
  colnames(Bfull) <- name_coefs(lags = lag, nthresh=nthresh, incNames = c("const", "trend"))
  add <- switch(include, "const"="const", "trend"="trend", "none"=NULL, "both" = c("const", "trend"))
  names(B) <- name_coefs(lags = lag, nthresh=nthresh, incNames = add)
  Bfull[colnames(Bfull) %in% names(B)] <-  B
  if(show.parMat) print(Bfull)
  
  npar_reg <- lag+2
  if(nthresh==1){
    BDown <- Bfull[seq_len(npar_reg)]
    BUp   <- Bfull[-seq_len(npar_reg)]
  } else if(nthresh==2){
    BDown <- Bfull[seq_len(npar_reg)]
    BMiddle <- Bfull[seq_len(npar_reg)+npar_reg]
    BUp <- Bfull[seq_len(npar_reg)+2*npar_reg]
  }
  
  
  
  ### MAIN loop
  
  thDelay <- thDelay+1
  
  #initial values
  Yb <- vector("numeric", length=length(y))		#Delta Y term
  Yb[1:lag] <- y[1:lag]
  
  z2 <- vector("numeric", length=length(y))
  z2[1:lag] <- y[1:lag]
  resb <- c(rep(0,lag), innov)	
  
  if(nthresh==0){
    for(i in (lag+1):length(y)){
      y[i] <- sum(Bfull[1], # intercept
                  Bfull[2]*trend[i], #trend
                  Bfull[-c(1,2)] * y[i-c(1:lag)], # lags
                  resb[i],
                  exo[i]) #residuals
      regime[i] <- 1
    }
  } else if(nthresh==1){
    for(i in (lag+1):length(y)){
      # switch every time the coef matrix to use
      if(round(z2[i-thDelay], round_digits) <= Thresh) {
        B_here <-  BDown
        regime[i] <- 1
      } else {
        B_here <-  BUp
        regime[i] <- 2
      }
      #recursive formula: cont, trend, lags, residuals
      y[i] <- sum(B_here[1], B_here[2]*trend[i], B_here[-c(1,2)] * y[i-c(1:lag)], resb[i], exo[i])
      z2[i] <- y[i]
    }
  } else if(nthresh==2){
    for(i in (lag+1):length(y)){
      # switch every time the coef matrix to use
      if(round(z2[i-thDelay],round_digits)<=Thresh[1]) {
        B_here <-  BDown
        regime[i] <- 1
      } else if(round(z2[i-thDelay], round_digits)>Thresh[2]) {
        B_here <-  BUp
        regime[i] <- 3
      } else{ 
        B_here <-  BMiddle
        regime[i] <- 2
      }
      #recursive formula: cont, trend, lags, residuals
      y[i] <- sum(B_here[1], B_here[2]*trend[i], B_here[-c(1,2)] * y[i-c(1:lag)], resb[i], exo[i])
      z2[i] <- y[i]
    }
  }
  
  res <- round(y, round_digits)
  if(!returnStarting) {
    res <- res[-seq_len(lag)] 
    regime <- regime[-seq_len(lag)] 
  } else {
    regime[seq_len(lag)]  <-  NA
  }
  if(add.regime) res <- cbind(res, regime)
  res
}

#' @rdname setar.sim
#' @export
setar.boot <- function(setarObject, boot.scheme = c("resample", "resample_block", "wild1", "wild2", "check"),
                       seed = NULL, ...){
  
  boot.scheme <-  match.arg(boot.scheme)
  mod <- setarObject$model.specific
  nthresh <- mod$nthresh
  
  y_orig <- setarObject$str$x
  T_full <- length(y_orig)
  k <- setarObject$k
  lags <- setarObject$str$m
  t <-  T_full- lags
  include <- setarObject$include
  
  if(inherits(setarObject,"linear")){
    B <- coef(setarObject)
    Thresh <-  thDelay <- NA # irrelevant
  }
  
  if(inherits(setarObject,"setar")){
    
    ## B: no threshold!
    coefs_mod <- coef(setarObject)
    TotNpar <- length(coefs_mod)-nthresh
    B <- coefs_mod[seq_len(TotNpar)]
    
    Thresh <- getTh(coefs_mod)
    thDelay <- mod$thDelay
  }
  
  ## retrieve starting values
  starts <- y_orig[1:lags]
  
  ## residuals, boot them
  resids <- residuals(setarObject)[-c(1:lags)]
  if(!is.null(seed)) set.seed(seed) 
  innov <- resample_vec(resids, boot.scheme = boot.scheme, seed=seed)
  
  ##
  setar.gen(B = B, lag = lags,
            nthresh = nthresh, Thresh = Thresh,
            thDelay = thDelay, 
            include= include, 
            starting = starts,  
            innov = innov, n = t, ...)
}

#'@rdname setar.sim
#'@param linearObject Bootstrap: the \code{\link{linear}} object to resample data from.
#' @export
linear.boot <- function(linearObject, boot.scheme = c("resample", "resample_block", "wild1", "wild2", "check"),
                       seed = NULL, ...){
  setar.boot(setarObject = linearObject, boot.scheme = boot.scheme, seed = seed, ...)
}

  
#'@rdname setar.sim
#' @export
setar.sim <- function(B, n=200, lag=1, include = c("const", "trend","none", "both"),  
                      nthresh=1, Thresh,
                      starting=NULL, innov=rnorm(n), ...){
  
  include <- match.arg(include)
  setar.gen(B=B, n=n, lag=lag, include = include,  
            nthresh = nthresh, Thresh = Thresh,
            starting=starting, innov=innov, ...)
}

#'@rdname setar.sim
#' @export
linear.sim <- function(B, n=200, lag=1, include = c("const", "trend","none", "both"),  
                       starting=NULL, innov=rnorm(n), ...){
  include <- match.arg(include)
  setar.sim(B = B, n=n, lag=lag, include = include,  
            nthresh=0, starting = starting, innov = innov, ...)
}





# if(FALSE){
#   library(tsDyn)
#   # environment(setar.sim)<-environment(star)
#   
#   ##Simulation of a TAR with 1 threshold
#   Bvals <- c(2.9,-0.4,-0.1,-1.5, 0.2,0.3)
#   sim<-setar.sim(B=Bvals,lag=2, type="simul", nthresh=1, Thresh=2, starting=c(2.8,2.2))
#   mean(ifelse(sim>2,1,0))	#approximation of values over the threshold
#   
#   #check the result
#   selectSETAR(sim, m=2, criterion="SSR")
#   selectSETAR(sim, m=2, th=list(around=2, ngrid=20))
#   
#   
#   ##Bootstrap a TAR with two threshold (three regimes)
#   sun<-(sqrt(sunspot.year+1)-1)*2
#   setar.sim(data=sun,nthresh=2, type="boot", Thresh=c(6,9))
#   
#   ##Check the bootstrap
#   checkBoot<-setar.sim(data=sun,nthresh=0, type="check", Thresh=6.14)
#   cbind(checkBoot,sun)
#   #prob with the digits!
#   
#   ###linear object
#   lin<-linear(sun, m=1)
#   checkBootL<-setar.sim(setarObject=lin, type="check")
#   cbind(checkBootL,sun)
#   linear(checkBootL, m=1)
#   ###setar object
#   setarSun<-setar(sun, m=2, nthresh=1)
#   checkBoot2<-setar.sim(setarObject=setarSun, type="check")
#   cbind(checkBoot2,sun)
# 
#   #does not work
# 
#   setarSun<-setar(sun, m=3, nthresh=2)
#   checkBoot3<-setar.sim(setarObject=setarSun, type="check")
#   cbind(checkBoot3,sun)
#   #ndig approach: works with m=2, m=3, m=4
#   #no ndig approach: output has then more digits than input
# 
# }
