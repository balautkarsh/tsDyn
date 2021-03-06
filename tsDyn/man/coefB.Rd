% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/coefECT.R
\name{coefB}
\alias{coefB}
\alias{coefB.VECM}
\alias{coefB.ca.jo}
\alias{coefA}
\alias{coefA.VECM}
\alias{coefA.ca.jo}
\alias{coefPI}
\title{Extract cointegration parameters A, B and PI}
\usage{
coefB(object, ...)

\method{coefB}{VECM}(object, ...)

\method{coefB}{ca.jo}(object, r = 1, normalize = TRUE, ...)

coefA(object, ...)

\method{coefA}{VECM}(object, ...)

\method{coefA}{ca.jo}(object, r = 1, normalize = TRUE, ...)

coefPI(object, ...)
}
\arguments{
\item{object}{An object of class \code{\link{VECM}}, \code{\link[urca]{ca.jo}}}

\item{r}{The cointegrating rank}

\item{normalize}{Whether to normalize the A/B coefficients. See details}

\item{\ldots}{Further arguments passed to methods}
}
\value{
A matrix containing the coefficients
}
\description{
Extract parameters in VECM: adjustment coefficients \code{A}, 
cointegrating coefficients \code{B} , or the composite matrix \code{PI}
}
\details{
The functions extract the parameters from a VECM with \eqn{K} variables 
and rank \eqn{r}:
  \describe{
   \item{A}{Adjustment coefficients, of dim \eqn{K \times r}}
   \item{B}{Cointegrating coefficients, of dim \eqn{K \times r}}
   \item{Pi}{Matrix \eqn{\Pi=A B^{'}}, of dim \eqn{K \times K}}
   }
   Coefficients are extracted from a VECM in package \code{tsDyn}, or from a VECM 
   obtained in package \code{urca} from \code{\link[urca]{ca.jo}} or \code{\link[urca]{cajorls}}. 
   
   Note that by default, the A and B coefficients returned are normalized (see below). This is 
   the case for results obtained from \code{\link{VECM}}/\code{\link{lineVar}} and 
   \code{\link[urca]{cajorls}}, while for \code{\link[urca]{ca.jo}}, the user has the choice
   (but normalize=TRUE by default), in which case the rank \code{r} is also to be specified.
   The normalization is the Phillips triangular representation,  as suggested by Johansen (1995, p. 72), 
   standardising  the first \eqn{r\times r} coefficients to \eqn{I_r}:
   \describe{
     \item{B}{\eqn{B_{norm}=B (c^{'}B)^{-1}} with \eqn{c=(I_r,0_{K-r,r})^{'}}}
     \item{A}{\eqn{A_{norm}=AB^{'}c}}
   }
   Finally, note that the function also apply to objects obtained from tests of class 
   \code{ca.jo.test} (from \code{\link[urca]{blrtest}} etc...). Care should be taken 
   however, since the normalization might override the restrictions imposed.
}
\examples{
data(barry)
vecm <- VECM(barry,  lag=1, estim="ML")
vecm_r2 <- VECM(barry,  lag=1, estim="ML", r=2)

## extract coefficients:
coefA(vecm)
coefB(vecm)
coefPI(vecm)
coefB(vecm_r2)
coefPI(vecm_r2)

## Beta-Restricted VECM:
beta_vecm2 <- coefB(vecm_r2) 
beta_vecm2[3,2] <- 0.02
vecm_r2_rest <- VECM(barry,  lag=1, estim="ML", r=2, beta=beta_vecm2)
round(coefB(vecm_r2_rest),5)

## Package vars/urca
if(require(urca)){
 vecm_ur <- ca.jo(barry, K=2)
 coefB(vecm_ur)
 coefB(vecm_ur,r=2)
 coefB(cajorls(vecm_ur, r=2))
 all.equal(coefB(vecm), coefB(vecm_ur), check.attributes=FALSE)
 all.equal(coefB(vecm_r2), coefB(vecm_ur, r=2), check.attributes=FALSE)
}
}
\references{
Johansen, Soren, (1995), Likelihood-Based Inference in Cointegrated Vector Autoregressive Models, Oxford University Press
}
\author{
Matthieu Stigler
}
