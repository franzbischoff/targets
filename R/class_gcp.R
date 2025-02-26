#' @export
store_class_repository.gcp <- function(repository, store, format) {
  format <- gsub(pattern = "\\&.*$", replacement = "", x = format)
  c(
    sprintf("tar_gcp_%s", format),
    "tar_gcp",
    "tar_cloud",
    if_any("tar_external" %in% class(store), character(0), "tar_external"),
    class(store)
  )
}

#' @export
store_assert_repository_setting.gcp <- function(repository) {
}

#' @export
store_produce_path.tar_gcp <- function(store, name, object, path_store) {
  store_produce_gcp_path(
    store = store,
    name = name,
    object = object,
    path_store = path_store
  )
}

store_produce_gcp_path <- function(store, name, object, path_store) {
  bucket <- store$resources$gcp$bucket %|||% store$resources$bucket
  tar_assert_nonempty(bucket)
  tar_assert_chr(bucket)
  tar_assert_scalar(bucket)
  tar_assert_nzchar(bucket)
  prefix <- store$resources$gcp$prefix %|||%
    store$resources$prefix %|||%
    tar_path_objects_dir_cloud()
  tar_assert_nonempty(prefix)
  tar_assert_chr(prefix)
  tar_assert_scalar(prefix)
  key <- file.path(prefix, name)
  tar_assert_nzchar(key)
  bucket <- paste0("bucket=", bucket)
  key <- paste0("key=", key)
  c(bucket, key)
}

store_gcp_bucket <- function(path) {
  store_gcp_path_field(path = path, pattern = "^bucket=")
}

store_gcp_key <- function(path) {
  store_gcp_path_field(path = path, pattern = "^key=")
}

store_gcp_version <- function(path) {
  out <- store_gcp_path_field(path = path, pattern = "^version=")
  if_any(length(out) && nzchar(out), out, NULL)
}

store_gcp_path_field <- function(path, pattern) {
  keyvalue_field(x = path, pattern = pattern)
}

# Semi-automated tests of GCP GCS integration live in tests/gcp/. # nolint
# These tests should not be fully automated because they
# automatically create buckets and upload data,
# which could put an unexpected and unfair burden on
# external contributors from the open source community.
# nocov start
#' @export
store_read_object.tar_gcp <- function(store) {
  path <- store$file$path
  key <- store_gcp_key(path)
  bucket <- store_gcp_bucket(path)
  scratch <- path_scratch(
    path_store = tempdir(),
    pattern = basename(store_gcp_key(path))
  )
  on.exit(unlink(scratch))
  dir_create(dirname(scratch))
  seconds_interval <- store$resources$network$seconds_interval %|||% 1
  seconds_timeout <- store$resources$network$seconds_timeout %|||% 30
  max_tries <- store$resources$network$max_tries %|||% Inf
  verbose <- store$resources$network$verbose %|||% TRUE
  retry_until_true(
    fun = ~{
      gcp_gcs_download(
        key = key,
        bucket = bucket,
        file = scratch,
        version = store_gcp_version(path),
        verbose = store$resources$gcp$verbose %|||% FALSE
      )
      TRUE
    },
    seconds_interval = seconds_interval,
    seconds_timeout = seconds_timeout,
    max_tries = max_tries,
    catch_error = TRUE,
    message = sprintf("Cannot download object %s from bucket %s", key, bucket),
    verbose = verbose
  )
  store_convert_object(store, store_read_path(store, scratch))
}

#' @export
store_exist_object.tar_gcp <- function(store, name = NULL) {
  path <- store$file$path
  gcp_gcs_exists(
    key = store_gcp_key(path),
    bucket = store_gcp_bucket(path),
    version = store_gcp_version(path),
    verbose = store$resources$gcp$verbose %|||% FALSE
  )
}

#' @export
store_delete_object.tar_gcp <- function(store, name = NULL) {
  path <- store$file$path
  key <- store_gcp_key(path)
  bucket <- store_gcp_bucket(path)
  version <- store_gcp_version(path)
  message <- paste(
    "could not delete target %s from gcp bucket %s key %s.",
    "Either delete the object manually in the gcp web console",
    "or call tar_invalidate(%s) to prevent the targets package",
    "from trying to delete it.\nMessage: "
  )
  message <- sprintf(message, name, bucket, key, name)
  tryCatch(
    gcp_gcs_delete(
      key = key,
      bucket =  bucket,
      version = version,
      verbose = store$resources$gcp$verbose %|||% FALSE
    ),
    error = function(condition) {
      tar_throw_validate(message, conditionMessage(condition))
    }
  )
}



#' @export
store_upload_object.tar_gcp <- function(store) {
  on.exit(unlink(store$file$stage, recursive = TRUE, force = TRUE))
  store_upload_object_gcp(store)
}

store_upload_object_gcp <- function(store) {
  key <- store_gcp_key(store$file$path)
  bucket <- store_gcp_bucket(store$file$path)
  seconds_interval <- store$resources$network$seconds_interval %|||% 1
  seconds_timeout <- store$resources$network$seconds_timeout %|||% 30
  max_tries <- store$resources$network$max_tries %|||% Inf
  verbose <- store$resources$network$verbose %|||% TRUE
  envir <- new.env(parent = emptyenv())
  if_any(
    file_exists_stage(store$file),
    retry_until_true(
      ~{
        envir$head <- gcp_gcs_upload(
          file = store$file$stage,
          key = key,
          bucket = bucket,
          metadata = list("targets-hash" = store$file$hash),
          predefined_acl = store$resources$gcp$predefined_acl %|||% "private",
          verbose = store$resources$gcp$verbose %|||% FALSE
        )
        TRUE
      },
      seconds_interval = seconds_interval,
      seconds_timeout = seconds_timeout,
      max_tries = max_tries,
      catch_error = TRUE,
      message = sprintf("Cannot upload to object %s bucket %s", key, bucket),
      verbose = verbose
    ),
    tar_throw_file(
      "Cannot upload non-existent gcp staging file ",
      store$file$stage,
      " to key ",
      key,
      ". The target probably encountered an error."
    )
  )
  path <- grep(
    pattern = "^version=",
    x = store$file$path,
    value = TRUE,
    invert = TRUE
  )
  store$file$path <- c(path, paste0("version=", envir$head$generation))
  invisible()
}

#' @export
store_ensure_correct_hash.tar_gcp <- function(store, storage, deployment) {
}

#' @export
store_has_correct_hash.tar_gcp <- function(store) {
  path <- store$file$path
  bucket <- store_gcp_bucket(path)
  key <- store_gcp_key(path)
  version <- store_gcp_version(path)
  hash <- store_gcp_hash(
    key = key,
    bucket = bucket,
    version = version,
    verbose = store$resources$gcp$verbose %|||% FALSE
  )
  !is.null(hash) && identical(hash, store$file$hash)
}

store_gcp_hash <- function(key, bucket, version, verbose) {
  head <- gcp_gcs_head(
    key = key,
    bucket = bucket,
    version = version,
    verbose = verbose
  )
  head$metadata[["targets-hash"]]
}
# nocov end

#' @export
store_get_packages.tar_gcp <- function(store) {
  c("googleCloudStorageR", NextMethod())
}
