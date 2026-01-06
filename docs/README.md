# solti-monitoring/docs - Development Documentation

> **Development Reference and Strategy Documents**
> *Development notes, metrics strategies, and working documentation for the solti-monitoring collection.*

## Purpose

This directory contains development documentation for the solti-monitoring Ansible collection, including development diaries, strategy documents, and technical decision records.

## Document Index

### [DEVELOPMENT.md](DEVELOPMENT.md)

Development diary and working notes for solti-monitoring collection.

**For:** Developers (human)
**Topics:**

- Development progress and milestones
- Current work items
- Technical decisions
- Implementation notes
- Issues and resolutions

**Usage:** Track development progress, understand implementation decisions

### [METRICS_COLLECTION_STRATEGY.md](METRICS_COLLECTION_STRATEGY.md)

Strategy document for metrics collection architecture.

**For:** Developers and architects (human)
**Topics:**

- Telegraf metrics collection design
- InfluxDB storage strategy
- Metric naming conventions
- Collection intervals
- Storage considerations
- Performance optimization

**Usage:** Reference when implementing new metrics collection or troubleshooting metrics pipeline

## Organization Guidelines

### Development Documentation

Development docs should:

- Include timestamps for context
- Document decisions and rationale
- Link to related code/files
- Track issues and resolutions
- Be updated as work progresses

### Strategy Documents

Strategy docs should:

- Explain architectural decisions
- Document trade-offs considered
- Provide implementation guidance
- Include examples
- Reference industry best practices

## Related Documentation

- **[Root CLAUDE.md](../../CLAUDE.md)** - Multi-collection development context
- **[solti-monitoring CLAUDE.md](../CLAUDE.md)** - Collection-specific context
- **[solti-monitoring README](../README.md)** - User-facing documentation
- **[Role READMEs](../roles/)** - Individual role documentation

## Usage Notes

**Target Audience:** Primarily for developers working on solti-monitoring.

For user documentation, see:

- [solti-monitoring README.md](../README.md) - User guide
- Individual role READMEs in `roles/*/README.md`

For public philosophy and architecture:

- [solti-docs repository](https://github.com/jackaltx/solti-docs)

---

*Part of the SOLTI (Systems Oriented Laboratory Testing & Integration) project*
