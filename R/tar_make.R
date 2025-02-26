#' @title Run a pipeline of targets.
#' @export
#' @family pipeline
#' @description Run the pipeline you defined in the targets
#'   script file (default: `_targets.R`). `tar_make()`
#'   runs the correct targets in the correct order and stores the return
#'   values in `_targets/objects/`. Use [tar_read()] to read a target
#'   back into R, and see
#'   <https://docs.ropensci.org/targets/reference/index.html#clean>
#'   to manage output files.
#' @return `NULL` except if `callr_function = callr::r_bg()`, in which case
#'   a handle to the `callr` background process is returned. Either way,
#'   the value is invisibly returned.
#' @inheritParams tar_validate
#' @param names Names of the targets to build or check. Set to `NULL` to
#'   check/build all the targets (default). Otherwise, you can supply
#'   `tidyselect` helpers like [any_of()] and [starts_with()].
#'   Because [tar_make()] and friends run the pipeline in a new R session,
#'   if you pass a character vector to a tidyselect helper, you will need
#'   to evaluate that character vector early with `!!`, e.g.
#'   `tar_make(names = any_of(!!your_vector))`.
#'   Applies to ordinary targets (stem) and whole dynamic branching targets
#'   (patterns) but not to individual dynamic branches.
#' @param shortcut Logical of length 1, how to interpret the `names` argument.
#'   If `shortcut` is `FALSE` (default) then the function checks
#'   all targets upstream of `names` as far back as the dependency graph goes.
#'   `shortcut = TRUE` increases speed if there are a lot of
#'   up-to-date targets, but it assumes all the dependencies
#'   are up to date, so please use with caution.
#'   It relies on stored metadata for information about upstream dependencies.
#'   `shortcut = TRUE` only works if you set `names`.
#' @param reporter Character of length 1, name of the reporter to user.
#'   Controls how messages are printed as targets run in the pipeline.
#'   Defaults to `tar_config_get("reporter_make")`. Choices:
#'   * `"silent"`: print nothing.
#'   * `"summary"`: print a running total of the number of each targets in
#'     each status category (queued, started, skipped, build, canceled,
#'     or errored). Also show a timestamp (`"%H:%M %OS2"` `strptime()` format)
#'     of the last time the progress changed and printed to the screen.
#'   * `"timestamp"`: same as the `"verbose"` reporter except that each
#'     .message begins with a time stamp.
#'   * `"timestamp_positives"`: same as the `"timestamp"` reporter
#'     except without messages for skipped targets.
#'   * `"verbose"`: print messages for individual targets
#'     as they start, finish, or are skipped. Each individual
#'     target-specific time (e.g. "3.487 seconds") is strictly the
#'     elapsed runtime of the target and does not include
#'     steps like data retrieval and output storage.
#'   * `"verbose_positives"`: same as the `"verbose"` reporter
#'     except without messages for skipped targets.
#' @param seconds_interval Positive numeric of length 1 with the minimum
#'   number of seconds between saves to the metadata and progress data.
#'   Also controls how often the reporter prints progress messages.
#'   Higher values generally make the pipeline run faster, but unsaved
#'   work (in the event of a crash) is not up to date.
#'   When a target starts or the pipeline ends,
#'   everything is saved/printed immediately,
#'   regardless of `seconds_interval`.
#' @param garbage_collection Logical of length 1. For a `crew`-integrated
#'   pipeline, whether to run garbage collection on the main process
#'   before sending a target
#'   to a worker. Ignored if `tar_option_get("controller")` is `NULL`.
#'   Independent from the `garbage_collection` argument of [tar_target()],
#'   which controls garbage collection on the worker.
#' @param use_crew Logical of length 1, whether to use `crew` if the
#'   `controller` option is set in `tar_option_set()` in the target script
#'   (`_targets.R`). See <https://books.ropensci.org/targets/crew.html>
#'   for details.
#' @param terminate_controller Logical of length 1. For a `crew`-integrated
#'   pipeline, whether to terminate the controller after stopping
#'   or finishing the pipeline. This should almost always be set to `TRUE`,
#'   but `FALSE` combined with `callr_function = NULL`
#'   will allow you to get the running controller using
#'   `tar_option_get("controller")` for debugging purposes.
#'   For example, `tar_option_get("controller")$summary()` produces a
#'   worker-by-worker summary of the work assigned and completed,
#'   `tar_option_get("controller")$queue` is the list of unresolved tasks,
#'   and `tar_option_get("controller")$results` is the list of
#'   tasks that completed but were not collected with `pop()`.
#'   You can manually terminate the controller with
#'   `tar_option_get("controller")$summary()` to close down the dispatcher
#'   and worker processes.
#' @examples
#' if (identical(Sys.getenv("TAR_EXAMPLES"), "true")) { # for CRAN
#' tar_dir({ # tar_dir() runs code from a temp dir for CRAN.
#' tar_script({
#'   list(
#'     tar_target(y1, 1 + 1),
#'     tar_target(y2, 1 + 1),
#'     tar_target(z, y1 + y2)
#'   )
#' }, ask = FALSE)
#' tar_make(starts_with("y")) # Only processes y1 and y2.
#' # Distributed computing with crew:
#' if (requireNamespace("crew", quietly = TRUE)) {
#' tar_script({
#'   tar_option_set(controller = crew::controller_local())
#'   list(
#'     tar_target(y1, 1 + 1),
#'     tar_target(y2, 1 + 1),
#'     tar_target(z, y1 + y2)
#'   )
#' }, ask = FALSE)
#' tar_make()
#' }
#' })
#' }
tar_make <- function(
  names = NULL,
  shortcut = targets::tar_config_get("shortcut"),
  reporter = targets::tar_config_get("reporter_make"),
  seconds_interval = targets::tar_config_get("seconds_interval"),
  callr_function = callr::r,
  callr_arguments = targets::tar_callr_args_default(callr_function, reporter),
  envir = parent.frame(),
  script = targets::tar_config_get("script"),
  store = targets::tar_config_get("store"),
  garbage_collection = targets::tar_config_get("garbage_collection"),
  use_crew = targets::tar_config_get("use_crew"),
  terminate_controller = TRUE
) {
  force(envir)
  tar_assert_scalar(shortcut)
  tar_assert_lgl(shortcut)
  tar_assert_flag(reporter, tar_reporters_make())
  tar_assert_callr_function(callr_function)
  tar_assert_list(callr_arguments)
  tar_assert_dbl(seconds_interval)
  tar_assert_scalar(seconds_interval)
  tar_assert_none_na(seconds_interval)
  tar_assert_ge(seconds_interval, 0)
  tar_assert_lgl(garbage_collection)
  tar_assert_scalar(garbage_collection)
  tar_assert_none_na(garbage_collection)
  tar_assert_lgl(terminate_controller)
  tar_assert_scalar(terminate_controller)
  tar_assert_none_na(terminate_controller)
  targets_arguments <- list(
    path_store = store,
    names_quosure = rlang::enquo(names),
    shortcut = shortcut,
    reporter = reporter,
    seconds_interval = seconds_interval,
    garbage_collection = garbage_collection,
    use_crew = use_crew,
    terminate_controller = terminate_controller
  )
  out <- callr_outer(
    targets_function = tar_make_inner,
    targets_arguments = targets_arguments,
    callr_function = callr_function,
    callr_arguments = callr_arguments,
    envir = envir,
    script = script,
    store = store,
    fun = "tar_make"
  )
  invisible(out)
}

tar_make_inner <- function(
  pipeline,
  path_store,
  names_quosure,
  shortcut,
  reporter,
  seconds_interval,
  garbage_collection,
  use_crew,
  terminate_controller
) {
  names <- tar_tidyselect_eval(names_quosure, pipeline_get_names(pipeline))
  controller <- tar_option_get("controller")
  if (is.null(controller) || (!use_crew)) {
    pipeline_reset_deployments(pipeline)
    queue <- if_any(
      pipeline_uses_priorities(pipeline),
      "parallel",
      "sequential"
    )
    local_init(
      pipeline = pipeline,
      meta = meta_init(path_store = path_store),
      names = names,
      shortcut = shortcut,
      queue = queue,
      reporter = reporter,
      seconds_interval = seconds_interval,
      envir = tar_option_get("envir")
    )$run()
  } else {
    tar_assert_package("crew (>= 0.3.0)")
    crew_init(
      pipeline = pipeline,
      meta = meta_init(path_store = path_store),
      names = names,
      shortcut = shortcut,
      queue = "parallel",
      reporter = reporter,
      seconds_interval = seconds_interval,
      garbage_collection = garbage_collection,
      envir = tar_option_get("envir"),
      controller = controller,
      terminate_controller = terminate_controller
    )$run()
  }
  invisible()
}
