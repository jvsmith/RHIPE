#' Report Status Of A MapReduce Job
#'
#' Returns the status of an running MapReduce job. 
#'
#' @param job The parameter \code{job} can either be a string with the format
#'   \emph{job_datetime_id} (e.g. \emph{job_201007281701_0274}) or the value
#'   returned from \code{rhex} with the \code{async} option set to TRUE.
#' @param mon.sec If \code{mon.sec} is greater than 0, a small data frame
#'   indicating the progress will be returned every \code{mon.sec} seconds.
#' @param autokill If \code{autokill} is TRUE, then any R errors caused by the
#'   map/reduce code will cause the job to be killed.
#' @param verbose If \code{verbose} is TRUE, also provided is the state of the
#'   job, the duration in seconds, a data frame with columns for the Map and
#'   Reduce phase. This data frame summarizes the number of tasks, the percent
#'   complete, and the number of tasks that are pending, running, complete or
#'   have failed. In addition the list has an element that consists of both
#'   user defined and Hadoop MapReduce built in counters (counters can be user
#'   defined with a call to \code{rhcounter}).
#' @param showErrors If TRUE display errors from R in MapReduce tasks.
#' @return a list of the current state
#' @author Saptarshi Guha
#' @note This function does something different depending on if it is used in
#' MapReduce expression during a MapReduce task.  In a MapReduce task use this
#' function to REPORT the status of your job to Hadoop.
#' 
#' From the user side, this displays the status of a running MapReduce job and
#' reports information accumulated about the Hadoop job.
#' 
#' The parameter \code{job}
#' can either be a string with the format \emph{job_datetime_id} (e.g.
#' \emph{job_201007281701_0274}) or the value returned from \code{rhex} with
#' the \code{async} option set to TRUE.
#'
#' @seealso \code{\link{rhex}}, \code{\link{rhmr}}, \code{\link{rhkill}}
#' @keywords MapReduce job status
#' @export
rhstatus <- function(job,mon.sec=5,autokill=TRUE, showErrors=TRUE,verbose=FALSE){
  if(class(job)!="jobtoken" && class(job)!="character" ) stop("Must give a jobtoken object(as obtained from rhex)")
  if(class(job)=="character") id <- job else {
    job <- job[[1]]
    id <- job[['job.id']]
  }
  if(mon.sec<=0) {
    return(Rhipe:::.rhstatus(id,autokill,showErrors))
  }else{
    while(TRUE){
      y <- .rhstatus(id,autokill=TRUE,showErrors)
      cat(sprintf("\n[%s] Job: %s, State: %s, Duration: %s\nURL:%s\n",date(),id,y$state,y$duration,y$tracking))
      print(y$progress)
      if(verbose){
        print(y$counters)
      }
      if(!(y$state %in% c("PREP","RUNNING"))) break;
      cat(sprintf("Waiting %s seconds\n", mon.sec))
      Sys.sleep(max(1,as.integer(mon.sec)))
    }
    return(y)
  }
}

.rhstatus <- function(id,autokill=FALSE,showErrors=FALSE){
  result <- Rhipe:::send.cmd(rhoptions()$child$handle, list("rhstatus", list(id, as.integer(showErrors))))[[1]]
  d <- data.frame("pct"=result[[3]],"numtasks"=c(result[[4]][1],result[[5]][[1]]),
                  "pending"=c(result[[4]][2],result[[5]][[2]]),
                  "running" = c(result[[4]][3],result[[5]][[3]]),
                  "complete" = c(result[[4]][4],result[[5]][[4]]),
                  "killed" = c(result[[4]][5],result[[5]][[5]]),
                  "failed_attempts" = c(result[[4]][6],result[[5]][[6]]),
                  "killed_attempts" = c(result[[4]][7],result[[5]][[7]])
                  )

  rownames(d) <- c("map","reduce")
  duration = result[[2]]
  state = result[[1]]
  errs=unique(result[[7]])
  haveRError <- FALSE

  if(!is.null(result[[6]]$R_ERRORS)) {
    ## I treat these errors differently from other types
    ## not sure if thats need, if not, this code can be eliminated
    ## and errs can be extended by R_ERRORS
    haveRError <- TRUE
    message(sprintf("There were R errors, showing 30:"))
    v <- unique(names(sort(result[[6]]$R_ERRORS)))
    newr <- t(sapply(v,function(x){
        y <- strsplit(x,"\n")[[1]]
        f <- which(sapply(y,function(r) grep("(R ERROR)",r),USE.NAMES=FALSE)>=1)
        if(length(f)>0) c("R",paste(y[(f[1]+3):(f[2]-1)],collapse="\n")) else c("NR",x)
      },USE.NAMES=FALSE))
    rerr <- head(newr[newr[,1]=="R",2],30)
    sapply(rerr,cat)
    if(autokill) {
      message(sprintf("Autokill is true and terminating %s", id))
      rhkill(id)
    }
  }
  if(length(errs)>0){
    if(showErrors){
      newr <- t(sapply(errs,function(x){
        y <- strsplit(x,"\n")[[1]]
        f <- which(sapply(y,function(r) grep("(R ERROR)",r),USE.NAMES=FALSE)>=1)
        if(length(f)>0) c("R",paste(y[(f[1]+3):(f[2]-1)],collapse="\n")) else c("NR",x)
      },USE.NAMES=FALSE))
      if(any(newr[,1]=="R")) {
        haveRError <- TRUE
        message(sprintf("There were R errors, showing at most 30:"))
        rerr <- head(newr[newr[,1]=="R",2],30)
        sapply(rerr,cat)
      }
      if(any(newr[,1]=="NR")) {
        message(sprintf("There were Hadoop specific errors (autokill will not kill job), showing at most 30:"))
        rerr <- head(newr[newr[,1]=="NR",2],30)
        sapply(rerr,cat)
      }
    }
    if(autokill && haveRError) {
      message(sprintf("Autokill is true and terminating %s", id))
      rhkill(id)
    }
  }
  if(any(d[,"failed_attempts"]>0) && !showErrors)
        warning("There are failed attempts, call rhstatus with  showErrors=TRUE. Note, some are fatal (e.g R errors) and some are not (e.g node failure)")
  if(haveRError) state <- "FAILED"
  return(list(state=state,duration=duration,progress=d, counters=result[[6]],rerrors=haveRError,errors=errs,tracking=result[[8]]));
}


# rhstatus <- function(x){
#   if(class(x)!="jobtoken" && class(x)!="character" ) stop("Must give a jobtoken object(as obtained from rhex)")
#   if(class(x)=="character") id <- x else {
#     x <- x[[1]]
#     id <- x[['job.id']]
#   }
#   result <- Rhipe:::doCMD(rhoptions()$cmd['status'],jobid =id,
#                           needoutput=TRUE,ignore.stderr=TRUE,verbose=FALSE)
#   d <- data.frame("pct"=result[[3]],"numtasks"=c(result[[4]][1],result[[5]][[1]]),
#                   "pending"=c(result[[4]][2],result[[5]][[2]]),
#                   "running" = c(result[[4]][3],result[[5]][[3]]),
#                   "complete" = c(result[[4]][4],result[[5]][[4]])
#                   ,"failed" = c(result[[4]][5],result[[5]][[5]]))
# 
#   rownames(d) <- c("map","reduce")
#   duration = result[[2]]
#   state = result[[1]]
#   return(list(state=state,duration=duration,progress=d, counters=result[[6]]));
# }
