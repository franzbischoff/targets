% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/tar_make_clustermq.R
\name{tar_make_clustermq}
\alias{tar_make_clustermq}
\title{Run a pipeline with persistent \code{clustermq} workers.}
\usage{
tar_make_clustermq(
  names = NULL,
  shortcut = targets::tar_config_get("shortcut"),
  reporter = targets::tar_config_get("reporter_make"),
  seconds_interval = targets::tar_config_get("seconds_interval"),
  workers = targets::tar_config_get("workers"),
  log_worker = FALSE,
  callr_function = callr::r,
  callr_arguments = targets::tar_callr_args_default(callr_function, reporter),
  envir = parent.frame(),
  script = targets::tar_config_get("script"),
  store = targets::tar_config_get("store"),
  garbage_collection = targets::tar_config_get("garbage_collection")
)
}
\arguments{
\item{names}{Names of the targets to build or check. Set to \code{NULL} to
check/build all the targets (default). Otherwise, you can supply
\code{tidyselect} helpers like \code{\link[=any_of]{any_of()}} and \code{\link[=starts_with]{starts_with()}}.
Because \code{\link[=tar_make]{tar_make()}} and friends run the pipeline in a new R session,
if you pass a character vector to a tidyselect helper, you will need
to evaluate that character vector early with \verb{!!}, e.g.
\code{tar_make(names = any_of(!!your_vector))}.
Applies to ordinary targets (stem) and whole dynamic branching targets
(patterns) but not to individual dynamic branches.}

\item{shortcut}{Logical of length 1, how to interpret the \code{names} argument.
If \code{shortcut} is \code{FALSE} (default) then the function checks
all targets upstream of \code{names} as far back as the dependency graph goes.
\code{shortcut = TRUE} increases speed if there are a lot of
up-to-date targets, but it assumes all the dependencies
are up to date, so please use with caution.
It relies on stored metadata for information about upstream dependencies.
\code{shortcut = TRUE} only works if you set \code{names}.}

\item{reporter}{Character of length 1, name of the reporter to user.
Controls how messages are printed as targets run in the pipeline.
Defaults to \code{tar_config_get("reporter_make")}. Choices:
\itemize{
\item \code{"silent"}: print nothing.
\item \code{"summary"}: print a running total of the number of each targets in
each status category (queued, started, skipped, build, canceled,
or errored). Also show a timestamp (\code{"\%H:\%M \%OS2"} \code{strptime()} format)
of the last time the progress changed and printed to the screen.
\item \code{"timestamp"}: same as the \code{"verbose"} reporter except that each
.message begins with a time stamp.
\item \code{"timestamp_positives"}: same as the \code{"timestamp"} reporter
except without messages for skipped targets.
\item \code{"verbose"}: print messages for individual targets
as they start, finish, or are skipped. Each individual
target-specific time (e.g. "3.487 seconds") is strictly the
elapsed runtime of the target and does not include
steps like data retrieval and output storage.
\item \code{"verbose_positives"}: same as the \code{"verbose"} reporter
except without messages for skipped targets.
}}

\item{seconds_interval}{Positive numeric of length 1 with the minimum
number of seconds between saves to the metadata and progress data.
Also controls how often the reporter prints progress messages.
Higher values generally make the pipeline run faster, but unsaved
work (in the event of a crash) is not up to date.
When a target starts or the pipeline ends,
everything is saved/printed immediately,
regardless of \code{seconds_interval}.}

\item{workers}{Positive integer, number of persistent \code{clustermq} workers
to create.}

\item{log_worker}{Logical, whether to write a log file for each worker.
Same as the \code{log_worker} argument of \code{clustermq::Q()}
and \code{clustermq::workers()}.}

\item{callr_function}{A function from \code{callr} to start a fresh clean R
process to do the work. Set to \code{NULL} to run in the current session
instead of an external process (but restart your R session just before
you do in order to clear debris out of the global environment).
\code{callr_function} needs to be \code{NULL} for interactive debugging,
e.g. \code{tar_option_set(debug = "your_target")}.
However, \code{callr_function} should not be \code{NULL} for serious
reproducible work.}

\item{callr_arguments}{A list of arguments to \code{callr_function}.}

\item{envir}{An environment, where to run the target R script
(default: \verb{_targets.R}) if \code{callr_function} is \code{NULL}.
Ignored if \code{callr_function} is anything other than \code{NULL}.
\code{callr_function} should only be \code{NULL} for debugging and
testing purposes, not for serious runs of a pipeline, etc.

The \code{envir} argument of \code{\link[=tar_make]{tar_make()}} and related
functions always overrides
the current value of \code{tar_option_get("envir")} in the current R session
just before running the target script file,
so whenever you need to set an alternative \code{envir}, you should always set
it with \code{tar_option_set()} from within the target script file.
In other words, if you call \code{tar_option_set(envir = envir1)} in an
interactive session and then
\code{tar_make(envir = envir2, callr_function = NULL)},
then \code{envir2} will be used.}

\item{script}{Character of length 1, path to the
target script file. Defaults to \code{tar_config_get("script")},
which in turn defaults to \verb{_targets.R}. When you set
this argument, the value of \code{tar_config_get("script")}
is temporarily changed for the current function call.
See \code{\link[=tar_script]{tar_script()}},
\code{\link[=tar_config_get]{tar_config_get()}}, and \code{\link[=tar_config_set]{tar_config_set()}} for details
about the target script file and how to set it
persistently for a project.}

\item{store}{Character of length 1, path to the
\code{targets} data store. Defaults to \code{tar_config_get("store")},
which in turn defaults to \verb{_targets/}.
When you set this argument, the value of \code{tar_config_get("store")}
is temporarily changed for the current function call.
See \code{\link[=tar_config_get]{tar_config_get()}} and \code{\link[=tar_config_set]{tar_config_set()}} for details
about how to set the data store path persistently
for a project.}

\item{garbage_collection}{Logical of length 1, whether to run garbage
collection on the main process before sending a target to a worker.
Independent from the \code{garbage_collection} argument of \code{\link[=tar_target]{tar_target()}},
which controls garbage collection on the worker.}
}
\value{
\code{NULL} except if \code{callr_function = callr::r_bg()}, in which case
a handle to the \code{callr} background process is returned. Either way,
the value is invisibly returned.
}
\description{
Run a pipeline with persistent \code{clustermq} workers.
}
\details{
\code{tar_make_clustermq()} is like \code{\link[=tar_make]{tar_make()}} except that targets
run in parallel on persistent workers. A persistent worker is an
R process that runs for a long time and builds multiple
targets during its lifecycle. Persistent
workers launch as soon as the pipeline reaches an outdated
target with \code{deployment = "worker"}, and they keep running
until the pipeline starts to wind down.

To configure \code{tar_make_clustermq()}, you must configure
the \code{clustermq} package. To do this, set global options
\code{clustermq.scheduler} and \code{clustermq.template}
inside the target script file (default: \verb{_targets.R}).
To read more about configuring \code{clustermq} for your scheduler, visit
\url{https://mschubert.github.io/clustermq/articles/userguide.html#configuration} # nolint
or \url{https://books.ropensci.org/targets/hpc.html}.
\code{clustermq} is not a strict dependency of \code{targets},
so you must install \code{clustermq} yourself.
}
\examples{
if (!identical(tolower(Sys.info()[["sysname"]]), "windows")) {
if (identical(Sys.getenv("TAR_EXAMPLES"), "true")) { # for CRAN
tar_dir({ # tar_dir() runs code from a temp dir for CRAN.
tar_script({
  options(clustermq.scheduler = "multiprocess") # Does not work on Windows.
  tar_option_set()
  list(tar_target(x, 1 + 1))
}, ask = FALSE)
tar_make_clustermq()
})
}
}
}
\seealso{
Other pipeline: 
\code{\link{tar_make_future}()},
\code{\link{tar_make}()}
}
\concept{pipeline}
