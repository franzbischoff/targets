# Use sparingly to minimize AWS costs.
# Verify all `targets` buckets are deleted afterwards.
# Use HMAC keys from Google Cloud.

endpoint <- "https://storage.googleapis.com"
region <- "auto"

client <- function() {
  paws::s3(
    config = list(
      endpoint = endpoint,
      region = region
    )
  )
}

tar_test("aws_s3_exists()", {
  bucket <- random_bucket_name()
  client()$create_bucket(Bucket = bucket)
  on.exit(aws_s3_delete_bucket(bucket, client()))
  expect_false(
    aws_s3_exists(
      key = "x",
      bucket = bucket,
      region = region,
      endpoint = endpoint
    )
  )
  tmp <- tempfile()
  writeLines("x", tmp)
  client()$put_object(Body = tmp, Key = "x", Bucket = bucket)
  expect_true(
    aws_s3_exists(
      key = "x",
      bucket = bucket,
      region = region,
      endpoint = endpoint
    )
  )
})

tar_test("aws_s3_head()", {
  bucket <- random_bucket_name()
  client()$create_bucket(Bucket = bucket)
  on.exit(aws_s3_delete_bucket(bucket, client()))
  tmp <- tempfile()
  writeLines("x", tmp)
  client()$put_object(Body = tmp, Key = "x", Bucket = bucket)
  head <- aws_s3_head(
    key = "x",
    bucket = bucket,
    region = region,
    endpoint = endpoint
  )
  expect_true(is.list(head))
  expect_true(is.character(head$ETag))
  expect_true(nzchar(head$ETag))
})

tar_test("aws_s3_download()", {
  bucket <- random_bucket_name()
  client()$create_bucket(Bucket = bucket)
  on.exit(aws_s3_delete_bucket(bucket, client()))
  tmp <- tempfile()
  writeLines("x", tmp)
  client()$put_object(Body = tmp, Key = "x", Bucket = bucket)
  tmp2 <- tempfile()
  expect_false(file.exists(tmp2))
  aws_s3_download(
    file = tmp2,
    key = "x",
    bucket = bucket,
    region = region,
    endpoint = endpoint
  )
  expect_equal(readLines(tmp2), "x")
})

tar_test("aws_s3_upload() without headers", {
  bucket <- random_bucket_name()
  client()$create_bucket(Bucket = bucket)
  on.exit(aws_s3_delete_bucket(bucket, client()))
  expect_false(
    aws_s3_exists(
      key = "x",
      bucket = bucket,
      region = region,
      endpoint = endpoint
    )
  )
  tmp <- tempfile()
  writeLines("x", tmp)
  aws_s3_upload(
    file = tmp,
    key = "x",
    bucket = bucket,
    region = region,
    endpoint = endpoint
  )
  expect_true(
    aws_s3_exists(
      key = "x",
      bucket = bucket,
      region = region,
      endpoint = endpoint
    )
  )
})

tar_test("aws_s3_upload() and download with metadata", {
  bucket <- random_bucket_name()
  client()$create_bucket(Bucket = bucket)
  on.exit(aws_s3_delete_bucket(bucket, client()))
  expect_false(
    aws_s3_exists(
      key = "x",
      bucket = bucket,
      region = region,
      endpoint = endpoint
    )
  )
  tmp <- tempfile()
  writeLines("x", tmp)
  aws_s3_upload(
    file = tmp,
    key = "x",
    bucket = bucket,
    metadata = list("custom" = "custom_metadata"),
    region = region,
    endpoint = endpoint
  )
  expect_true(
    aws_s3_exists(
      key = "x",
      bucket = bucket,
      region = region,
      endpoint = endpoint
    )
  )
  head <- aws_s3_head(
    key = "x",
    bucket = bucket,
    region = region,
    endpoint = endpoint
  )
  expect_equal(head$Metadata$custom, "custom_metadata")
  tmp2 <- tempfile()
  expect_false(file.exists(tmp2))
  aws_s3_download(
    file = tmp2,
    key = "x",
    bucket = bucket,
    region = region,
    endpoint = endpoint
  )
  expect_equal(readLines(tmp2), "x")
})

# Go through this one fully manually.
tar_test("upload twice, get the correct version", {
  skip("not working because GCP S3 interoperability does not get versions.")
  bucket <- random_bucket_name()
  client()$create_bucket(Bucket = bucket)
  on.exit(aws_s3_delete_bucket(bucket, client()))
  # Manually turn on bucket versioning in the GCP web console
  # (bucket details, "PROTECTION" tab).
  tmp <- tempfile()
  writeLines("first", tmp)
  head_first <- aws_s3_upload(
    file = tmp,
    key = "x",
    bucket = bucket,
    region = region,
    endpoint = endpoint,
    metadata = list("custom" = "first-meta")
  )
  v1 <- head_first$VersionId
  writeLines("second", tmp)
  head_second <- aws_s3_upload(
    file = tmp,
    key = "x",
    bucket = bucket,
    region = region,
    endpoint = endpoint,
    metadata = list("custom" = "second-meta")
  )
  v2 <- head_second$VersionId
  expect_true(
    aws_s3_exists(
      key = "x",
      bucket = bucket,
      region = region,
      endpoint = endpoint
    )
  )
  expect_true(
    aws_s3_exists(
      key = "x",
      bucket = bucket,
      region = region,
      endpoint = endpoint,
      version = v1
    )
  )
  expect_true(
    aws_s3_exists(
      key = "x",
      bucket = bucket,
      version = v2,
      region = region,
      endpoint = endpoint
    )
  )
  expect_false(
    aws_s3_exists(
      key = "x",
      bucket = bucket,
      region = region,
      endpoint = endpoint,
      version = "v3"
    )
  )
  h1 <- aws_s3_head(
    key = "x",
    bucket = bucket,
    region = region,
    endpoint = endpoint,
    version = v1
  )
  h2 <- aws_s3_head(
    key = "x",
    bucket = bucket,
    region = region,
    endpoint = endpoint,
    version = v2
  )
  expect_equal(h1$VersionId, v1)
  expect_equal(h2$VersionId, v2)
  expect_equal(h1$Metadata$custom, "first-meta")
  expect_equal(h2$Metadata$custom, "second-meta")
  unlink(tmp)
  aws_s3_download(
    file = tmp,
    key = "x",
    bucket = bucket,
    region = region,
    endpoint = endpoint,
    version = v1
  )
  expect_equal(readLines(tmp), "first")
  aws_s3_download(
    file = tmp,
    key = "x",
    bucket = bucket,
    region = region,
    endpoint = endpoint,
    version = v2
  )
  expect_equal(readLines(tmp), "second")
})

tar_test("multipart: upload twice, get the correct version", {
  skip("not working because GCP S3 interoperability does not get versions.")
  bucket <- random_bucket_name()
  client()$create_bucket(Bucket = bucket)
  on.exit(aws_s3_delete_bucket(bucket, client()))
  # Manually turn on bucket versioning in the GCP web console
  # (bucket details, "PROTECTION" tab).
  tmp <- tempfile()
  writeLines("first", tmp)
  head_first <- aws_s3_upload(
    file = tmp,
    key = "x",
    bucket = bucket,
    multipart = TRUE,
    region = region,
    endpoint = endpoint,
    metadata = list("custom" = "first-meta")
  )
  v1 <- head_first$VersionId
  writeLines("second", tmp)
  head_second <- aws_s3_upload(
    file = tmp,
    key = "x",
    bucket = bucket,
    multipart = TRUE,
    region = region,
    endpoint = endpoint,
    metadata = list("custom" = "second-meta")
  )
  v2 <- head_second$VersionId
  expect_true(
    aws_s3_exists(
      key = "x",
      bucket = bucket,
      region = region,
      endpoint = endpoint
    )
  )
  expect_true(
    aws_s3_exists(
      key = "x",
      bucket = bucket,
      region = region,
      endpoint = endpoint,
      version = v1
    )
  )
  expect_true(
    aws_s3_exists(
      key = "x",
      bucket = bucket,
      region = region,
      endpoint = endpoint,
      version = v2
    )
  )
  expect_false(
    aws_s3_exists(
      key = "x",
      bucket = bucket,
      region = region,
      endpoint = endpoint,
      version = "v3"
    )
  )
  h1 <- aws_s3_head(
    key = "x",
    bucket = bucket,
    region = region,
    endpoint = endpoint,
    version = v1
  )
  h2 <- aws_s3_head(
    key = "x",
    bucket = bucket,
    region = region,
    endpoint = endpoint,
    version = v2
  )
  expect_equal(h1$VersionId, v1)
  expect_equal(h2$VersionId, v2)
  expect_equal(h1$Metadata$custom, "first-meta")
  expect_equal(h2$Metadata$custom, "second-meta")
  unlink(tmp)
  aws_s3_download(
    file = tmp,
    key = "x",
    bucket = bucket,
    region = region,
    endpoint = endpoint,
    version = v1
  )
  expect_equal(readLines(tmp), "first")
  aws_s3_download(
    file = tmp,
    key = "x",
    bucket = bucket,
    region = region,
    endpoint = endpoint,
    version = v2
  )
  expect_equal(readLines(tmp), "second")
})

tar_test("graceful error on multipart upload", {
  bucket <- random_bucket_name()
  client()$create_bucket(Bucket = bucket)
  on.exit(aws_s3_delete_bucket(bucket, client()))
  tmp <- tempfile()
  writeBin(raw(1e4), tmp)
  expect_error(
    aws_s3_upload(
      file = tmp,
      key = "x",
      bucket = bucket,
      multipart = TRUE,
      region = region,
      endpoint = endpoint,
      part_size = 5e3
    ),
    class = "tar_condition_file"
  )
})
