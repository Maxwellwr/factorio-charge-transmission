# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/)
and this project adheres to [Semantic Versioning](http://semver.org/). Mostly.

<!-- markdownlint-disable MD022 MD024 MD032 -->

## [Unreleased]
### Added
- Description on bot charger, to hint at rotating mechanic
### Changed
- Remade the overtaxed graphic to be more intuitive and in line with the new warning basegame design
- Bots can be charged more than once a second (less than sucessful optimization removed)
- Made bot chargers respect `worker_robots_battery_modifier`
### Fixed
- Fixed crash if node was added to a roboport with a 0-width construction area
- Overtaxing now uses the transmitter's power drain limit, not the base's

## [0.3.2] - 2017-06-25
### Changed
- More referrals in README (issue reporters and forum thread)
### Fixed
- Disabled debug world creation

## [0.3.1] - 2017-06-20
### Added
- Changelog
- Referral in README for KoS
### Changed
- Reworked README for better compatability with Factorio's mod portal
- .gitignore ignores mod portal images (including icon)
- Mod metadata points at forum thread
### Fixed
- Backwards compatibility established with v0.1 (closed beta)

## 0.3.0 - 2017-06-16
### Added
- Bot charger (entity + tech)
- Custom overtaxing
- README as mod documentation

[Unreleased]: https://github.com/dustine/ChargeTransmission/compare/v0.3.2...HEAD
[0.3.2]: https://github.com/dustine/ChargeTransmission/compare/v0.3.1...v0.3.2
[0.3.1]: https://github.com/dustine/ChargeTransmission/compare/v0.3.0...v0.3.1