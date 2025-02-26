% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/tar_resources_fst.R
\name{tar_resources_fst}
\alias{tar_resources_fst}
\title{Target resources: \code{fst} storage formats}
\usage{
tar_resources_fst(compress = targets::tar_option_get("resources")$fst$compress)
}
\arguments{
\item{compress}{Numeric of length 1, \code{compress}
argument of \code{fst::write_fst()}. Defaults to \code{50}.}
}
\value{
Object of class \code{"tar_resources_fst"}, to be supplied
to the \code{fst} argument of \code{tar_resources()}.
}
\description{
Create the \code{fst} argument of \code{tar_resources()}
to specify optional settings for big data frame storage formats
powered by the \code{fst} R package.
See the \code{format} argument of \code{\link[=tar_target]{tar_target()}} for details.
}
\section{Resources}{

Functions \code{\link[=tar_target]{tar_target()}} and \code{\link[=tar_option_set]{tar_option_set()}}
each takes an optional \code{resources} argument to supply
non-default settings of various optional backends for data storage
and high-performance computing. The \code{tar_resources()} function
is a helper to supply those settings in the correct manner.

In \code{targets} version 0.12.2 and above, resources are inherited one-by-one
in nested fashion from \code{tar_option_get("resources")}.
For example, suppose you set
\code{tar_option_set(resources = tar_resources(aws = my_aws))},
where \code{my_aws} equals \code{tar_resources_aws(bucket = "x", prefix = "y")}.
Then, \verb{tar_target(data, get_data()} will have bucket \code{"x"} and
prefix \code{"y"}. In addition, if \code{new_resources} equals
\verb{tar_resources(aws = tar_resources_aws(bucket = "z")))}, then
\code{tar_target(data, get_data(), resources = new_resources)}
will use the new bucket \code{"z"}, but it will still use the prefix \code{"y"}
supplied through \code{tar_option_set()}. (In \code{targets} 0.12.1 and below,
options like \code{prefix} do not carry over from \code{tar_option_set()} if you
supply non-default resources to \code{tar_target()}.)
}

\examples{
# Somewhere in you target script file (usually _targets.R):
tar_target(
  name,
  command(),
  format = "fst_tbl",
  resources = tar_resources(
    fst = tar_resources_fst(compress = 100)
  )
)
}
\seealso{
Other resources: 
\code{\link{tar_resources_aws}()},
\code{\link{tar_resources_clustermq}()},
\code{\link{tar_resources_crew}()},
\code{\link{tar_resources_feather}()},
\code{\link{tar_resources_future}()},
\code{\link{tar_resources_gcp}()},
\code{\link{tar_resources_network}()},
\code{\link{tar_resources_parquet}()},
\code{\link{tar_resources_qs}()},
\code{\link{tar_resources_url}()},
\code{\link{tar_resources}()}
}
\concept{resources}
