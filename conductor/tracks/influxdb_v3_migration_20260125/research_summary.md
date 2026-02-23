# InfluxDB v3 Research Summary

This document summarizes the key differences between InfluxDB v2 and v3, focusing on architecture, installation, authentication, data model, and query languages.

## Architecture & Installation

*   **Core Engine:** InfluxDB v3 is a complete rewrite of the storage engine in Rust, built on technologies like Apache Arrow and Apache DataFusion for high-performance analytics.
*   **Installation:**
    *   Can be installed via a shell script, Docker, or manual binary download.
    *   The primary interface is the `influxd` server binary.
*   **Configuration:**
    *   Configuration is managed through command-line arguments or a config file.
    *   Key flags include `--node-id`, `--cluster-id`, and `--object-store` (e.g., `file` for local storage).
    *   A significant change is the move towards a disaggregated architecture where storage can be handled by an object store.

## Authentication

*   **Token-Based:** Authentication is primarily handled via bearer tokens.
*   **Compatibility:** It supports v2 token authentication for backward compatibility with existing clients.
*   **Admin & Permissions:** An initial admin token can be generated, and the system uses an Attribute-Based Access Control (ABAC) model for fine-grained permissions.
*   **Default Security:** Authorization is enabled by default, even for health-check endpoints.

## Data Model & Query Language

*   **Data Model:** The data model has been simplified and clarified:
    *   **Database:** A logical container for tables. Replaces the v2 concept of a "bucket".
    *   **Table:** Equivalent to a v2 "measurement".
    *   **Columns:** Tables consist of columns for time, tags (dictionary-encoded strings), and fields (various data types).
*   **Query Languages:**
    *   **SQL:** Native support for SQL is a major new feature.
    *   **InfluxQL:** The original InfluxDB query language is back and fully supported.
    *   **Flux:** The Flux language, which was central to InfluxDB v2, is now deprecated and not the primary query language in v3.

## Key Breaking Changes from v2 to v3

*   **Query Language:** The deprecation of Flux in favor of SQL and InfluxQL is the most significant breaking change. All queries written in Flux will need to be rewritten.
*   **No In-Place Upgrade:** There is no direct, in-place upgrade path from InfluxDB v2 to v3. Migration requires a full data export from the v2 instance and import into the new v3 instance.
*   **API Changes:** The underlying API has changed significantly. Applications and scripts that interact with the v2 API will need to be updated to work with the v3 API.
*   **Architectural Shift:** The concept of the "TICK" stack is less emphasized, as v3 is more focused on being a standalone, high-performance time-series database.
