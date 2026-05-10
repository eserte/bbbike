# BBBike Agent Instructions

Welcome, agent. This file provides context and guidelines for working with the BBBike repository.

## Project Overview

BBBike is a route-finder for cyclists, primarily focused on Berlin and Brandenburg, but extensible to other regions. It consists of a Perl/Tk desktop application, a CGI web interface, and numerous utilities for data processing (GPX, OSM, etc.).

## Core Components and Libraries

- **`bbbike.cgi`**: The main entry point for the web-based routing engine.
- **`Strassen.pm`**: The core interface for "bbd" (BBBike data) files.
- **`BBBikeUtil.pm`**: Provides utility functions like `bbbike_root()` and `bbbike_aux_dir()` for consistent path resolution.
- **`t/BBBikeTest.pm`**: The base module for the Perl test suite.

## Coding Conventions and Patterns

### Path Resolution
- When writing scripts in subdirectories (e.g., `miscsrc/`, `t/`), use `FindBin` to include repository libraries:
  ```perl
  use FindBin;
  use lib "$FindBin::RealBin/..", "$FindBin::RealBin/../lib";
  ```
- Prefer using `BBBikeUtil::bbbike_root()` for finding the base directory of the installation.

### ZIP Member Iteration
- When using `IO::Uncompress::Unzip->new` to iterate over ZIP members, the object is immediately positioned at the first member. To allow the use of `last` or `next` within the loop while ensuring the first member is processed, use a `while(1) { ... last if !$u->nextStream; }` pattern instead of `do { ... } while ($u->nextStream)`.

### Highlighting in Tampermonkey Scripts
- Scripts in `misc/tampermonkey/` should use `MutationObserver` and a `data-highlighted="true"` attribute to efficiently highlight links in dynamically loaded content while avoiding redundant processing.

## Testing and Verification

- **Running Tests**: Use `prove` to run tests. Representative test suites include `t/basic.t` (core functionality) and `t/miscsrc.t` (syntax/warning checks for scripts).
- **Environment Awareness**: Some environments may lack standard Perl modules like `LWP::UserAgent`, `CGI.pm`, or `HTML::Form`. Be cautious when running tests or syntax checks (`perl -c`) that rely on these.
- **PDF Tests**: Depend on `libimage-exiftool-perl`, `libpdf-create-perl`, and `libtext-unidecode-perl`.
- **GPX Utilities**: Require `XML::LibXML`, `IPC::Run`, `DateTime::Format::ISO8601`, and `Geo::Distance`.

## Continuous Integration and Infrastructure

- **GitHub Actions**: Primarily used for CI testing.
  - Note: Occasionally, network problems can occur during workflow execution, leading to failures in fetching required packages. If you encounter such failures, recognize them as transient infrastructure issues and do not attempt to fix or workaround them in the code.
- **OBS Support**: The project uses OpenSUSE Build Service (OBS) for newer Linux distributions. The environment variable `USE_ESERTE_OBS` enables and prioritizes OBS repository support.
- **Docker**: `miscsrc/docker-bbbike` is the primary tool for managing Docker-based builds and tests.

## Specific Functional Areas

- **Precipitation Adjustment**: `miscsrc/dwd-soil-update.pl` supports adjusting soil moisture values using DWD precipitation data via the `--adjust-by-precip` flag.
- **Fahrradstraßen**: Identified internally by the category code `RW7`.
- **Mudways Prognosis**: The pipeline in `plugins/SRTShortcuts.pm` calls `dwd-soil-update.pl` with `--adjust-by-precip` for accurate path condition forecasts.

## Documentation

- **README.english**: General installation and usage instructions.
- **bbbike.pod**: Main application documentation.
