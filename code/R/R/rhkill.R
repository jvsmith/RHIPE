#' Kill A MapReduce Job
#' 
#' This kills the MapReduce job with job identifier given by \code{job}. The
#' parameter \code{job} can either be string with the format
#' \emph{job_datetime_id} or the value returned from \code{rhex} with the
#' \code{async} option set to TRUE.
#' 
#' @param job The parameter \code{job} can either be string with the format
#'   \emph{job_datetime_id} or the value returned from \code{rhex} with the
#'   \code{async} option set to TRUE.
#' @author Saptarshi Guha
#' @return NULL
#' @seealso \code{\link{rhstatus}}, \code{\link{rhmr}}, \code{\link{rhjoin}},
#'   \code{\link{rhex}}
#' @export
rhkill <- function(job) {
  if(class(job)!="jobtoken" && class(job)!="character" ) stop("Must give a jobtoken object(as obtained from rhex)")
  if(class(job)=="character") id <- job else {
    job <- job[[1]]
    id <- job[['job.id']]
  }
  result <- Rhipe:::send.cmd(rhoptions()$child$handle,list("rhkill", list(id)))
}

# rhkill <- function(w,...){
#   if(class(w)=="jobtoken")
#     w= w[[1]][['job.id']] else {
#       if(length(grep("^job_",w))==0) w=paste("job_",w,sep="",collapse="")
#     }
#   system(command=paste(paste(Sys.getenv("HADOOP_BIN"),"hadoop",sep=.Platform$file.sep,collapse=""),"job","-kill",w,collapse=" "),...)
# }
